from django.db import models, connections
from django.db.models import Q
from pprint import pprint
import re
from django.db import connection
from datetime import datetime


class TestRun(models.Model):
  branch = models.CharField(max_length=100, blank=True, null=True)
  revision = models.CharField(max_length=256, blank=True, null=True)
  platform = models.CharField(max_length=100)
  dt = models.DateTimeField()
  bbnum = models.IntegerField()
  typ = models.CharField(max_length=32)
  info = models.CharField(max_length=255, blank=True, null=True)

  class Meta:
    managed = False
    db_table = 'test_run'

class TestFailure(models.Model):
  test_run_id = models.ForeignKey(TestRun,
    null=False,
    blank=False,
    db_column='test_run_id',
    primary_key=True,
    unique=False,
    on_delete=models.DO_NOTHING
  )
  test_name = models.CharField(max_length=100)
  test_variant = models.CharField(max_length=64)
  info_text = models.CharField(max_length=255, blank=True, null=True)
  failure_text = models.TextField(blank=True, null=True)

  class Meta:
    managed = False
    db_table = 'test_failure'
    unique_together = (('test_run_id', 'test_name', 'test_variant'),)





# def test_fcn():
#   test_run = TestRun.objects.all()
#   test_failure = TestFailure.objects.all()
#   builders = Builders.objects.all()

#   for tr in test_run:
#     print(tr.branch)
#     print(tr.revision)
#     print(tr.platform)
#     print(tr.dt)
#     print(tr.bbnum)
#     print(tr.typ)
#     print(tr.info)
#     break

#   for tf in test_failure:
#     print(tf.test_run_id)
#     print(tf.test_name)
#     print(tf.test_variant)
#     print(tf.info_text)
#     print(tf.failure_text)
#     # print(tf)
#     break

#   for b in builders:
#     # print(b)
#     print(b.name)
#     print(b.description)
#     print(b.name_hash)
#     break

#   return test_failure


# Create your models here.
# def select_test_failures(filters, include_failures=True):
#     available_filters = ["branch", "revision", "platform", "dt", "bbnum", "typ", "info", "test_name", "test_variant", "info_text", "failure_text"]
#     with connections['default'].cursor() as cursor:
#         sql_query = """SELECT
#             branch,
#             revision,
#             builders.id,
#             platform,
#             dt,
#             bbnum,
#             typ,
#             info"""
#         if include_failures is not None:
#             sql_query += """,
#             test_name,
#             test_variant,
#             info_text,
#             failure_text"""
#         sql_query += """
#             FROM
#                 test_run,
#                 builders"""
#         if include_failures is not None:
#             sql_query += """,
#                 test_failure"""
#         sql_query += """
#             WHERE """
#         if include_failures is not None:
#             sql_query += "test_run.id = test_failure.test_run_id AND platform = builders.name "

#         for f in available_filters:
#             if f in filters and filters[f] != '':
#                 sql_query += "AND " + f + " LIKE '%" + filters[f] + "%'"

#         limit = '100'
#         if 'limit' in filters and filters['limit'] != '':
#             limit = filters['limit']
#         sql_query += """
#             ORDER BY dt DESC
#             LIMIT """ + limit

#         cursor.execute(sql_query)
#         rows = cursor.fetchall()

#     return rows


def select_test_failures(filters, include_failures=True):
  available_filters = ["branch", "revision", "platform", "dt", "bbnum", "typ", "info", "test_name", "test_variant", "info_text", "failure_text"]
  with connections['default'].cursor() as cursor:
    sql_query = """SELECT
      branch,
      revision,
      builders.id,
      platform,
      dt,
      bbnum,
      typ,
      info"""
    if include_failures is not None:
      sql_query += """,
      test_name,
      test_variant,
      info_text,
      failure_text"""
    sql_query += """
      FROM
        test_run,
        builders"""
    if include_failures is not None:
      sql_query += """,
        test_failure"""
    sql_query += """
      WHERE """
    if include_failures is not None:
      sql_query += "test_run.id = test_failure.test_run_id AND platform = builders.name "

    for f in available_filters:
      if f in filters and filters[f] != '':
        sql_query += "AND " + f + " LIKE '%" + filters[f] + "%'"

    limit = '100'
    if 'limit' in filters and filters['limit'] != '':
      limit = filters['limit']
    sql_query += """
      ORDER BY dt DESC
      LIMIT """ + limit

    cursor.execute(sql_query)
    rows = cursor.fetchall()


  # New implementation

  limit = 5
  if 'limit' in filters and filters['limit'] != '':
    limit = int(filters['limit'])


  test_run_filters = None
  test_failure_filters = {}

  branch_regex_exp = [
    # Pattern: 10.?
    {
      'pattern': '^([0-9]{1,2}\.)(\?)$',
      # 'filter': [('branch__gte', 'AND')],
      'filter': [('branch__startswith', 'AND')],
      'replace': True
    },
    # Pattern: 10.1, 10.2, 5.5...
    {
      'pattern': '^([0-9]{1,2}\.)([0-9]{1,2})$',
      'filter': [('branch__exact', 'AND')],
      'replace': False
    },
    # Pattern: *10.1*, *10.2*...
    {
      'pattern': '^\*([0-9]{1,2}\.)([0-9]{1,2})\*$',
      'filter': [('branch__icontains', 'AND')],
      'replace': True
    },
    # Pattern *10.?*
    {
      'pattern': '^\*([0-9]{1,2}\.)(\?)\*$',
      # 'filter': [('branch__icontains', 'AND'), ('branch__gte', 'OR')],
      'filter': [('branch__icontains', 'AND'), ('branch__startswith', 'OR')],
      'replace': True
    },
  ]

  # Branch
  if filters['branch'] and 'branch' in available_filters:
    match = None
    search_string = filters['branch']
    q_objects = Q()

    for expression in branch_regex_exp:
      match = re.search(expression['pattern'], filters['branch'])
      if match is not None:
        if expression['replace']:
          search_string = re.sub('(\?)|(\*)', '', search_string)
          # print('search_string', search_string)

        for f in expression['filter']:
          if f[1] == 'OR':
            q_objects |= Q(**{f[0]: search_string})
          else:
            q_objects &= Q(**{f[0]: search_string})

        break

    if match is None:
      q_objects = Q(branch__icontains=search_string)

    test_run_filters = TestRun.objects.filter(q_objects)


  # Revision
  if filters['revision'] and 'revision' in available_filters:
    if test_run_filters is not None:
      test_run_filters = test_run_filters.filter(Q(revision__startswith=filters['revision']))
    else:
      test_run_filters = TestRun.objects.filter(Q(revision__startswith=filters['revision']))

  # Platform -- Might need adjustment
  if filters['platform'] and 'platform' in available_filters:
    if test_run_filters is not None:
      test_run_filters = test_run_filters.filter(Q(platform__icontains=filters['platform']))
    else:
      test_run_filters = TestRun.objects.filter(Q(platform__icontains=filters['platform']))

  # Build Number
  if filters['bbnum'] and 'bbnum' in available_filters:
    if test_run_filters is not None:
      test_run_filters = test_run_filters.filter(Q(bbnum__icontains=filters['bbnum']))
    else:
      test_run_filters = TestRun.objects.filter(Q(bbnum__icontains=filters['bbnum']))

  # Type
  if filters['typ'] and 'typ' in available_filters:
    if test_run_filters is not None:
      test_run_filters = test_run_filters.filter(Q(typ__icontains=filters['typ']))
    else:
      test_run_filters = TestRun.objects.filter(Q(typ__icontains=filters['typ']))

  # Run Info
  if filters['info'] and 'info' in available_filters:
    if test_run_filters is not None:
      test_run_filters = test_run_filters.filter(Q(info__icontains=filters['info']))
    else:
      test_run_filters = TestRun.objects.filter(Q(info__icontains=filters['info']))


  # Test Name
  if filters['test_name'] and 'test_name' in available_filters:
    if test_run_filters is not None:
      test_run_filters = test_run_filters.filter(Q(testfailure__test_name__icontains=filters['test_name']))
    else:
      test_run_filters = TestRun.objects.filter(Q(testfailure__test_name__icontains=filters['test_name']))



  print('query', test_run_filters.query)
  if test_run_filters is not None:
    test_run_filters = test_run_filters[0:limit]


  result = {
    'test_runs': test_run_filters,
    'test_failures': {},
    'builders': {}
  }
  # or_condition = Q()
  # for key, value in my_dict.items():
  #     or_condition.add(Q(**{key: value}), Q.OR)

  # regex_exp = '^([0-9]{1,2}\.)(\?)$|^([0-9]{1,2}\.)([0-9]{1,2})$|^\*([0-9]{1,2}\.)([0-9]{1,2})\*$'

  # TestFailure
  # print(TestRun._meta.get_fields())
      # test_run_filters.append('{0}__{1}'.format(field.name, 'iregex'))

  # for field in TestFailure._meta.get_fields():
  #   if field.name in filters and filters[field.name]:
  #     test_failure_filters = {
  #       '{0}__{1}'.format(field.name, 'iregex'): filters[field.name]
  #     }
      # test_run_filters.append('{0}__{1}={2}'.format(field.name, 'iregex', filters[field.name]))

  # regex_exp = 

  # filters = {
  #   '{0}__{1}'.format(field.name, 'iregex'): value
  #   for key, value in request.post.items()
  #   if key in ['filter1', 'filter2', 'filter3']
  # }
  # test_run_filters = ['{0}__{1}={2}'.format(k, 'iregex', v) for (k,v) in filters.items()]

  # print(test_run_filters)
  # print(test_failure_filters)
  # test_run_filters = {
  #   '{0}__{1}'.format('branch', 'iregex'): filters['branch'],
  #   '{0}__{1}'.format('revision', 'iregex'): filters['revision'],
  #   '{0}__{1}'.format('platform', 'iregex'): filters['platform'],
  #   '{0}__{1}'.format('dt', 'iregex'): filters['dt'],
  #   '{0}__{1}'.format('bbnum', 'iregex'): filters['bbnum'],
  #   '{0}__{1}'.format('typ', 'iregex'): filters['typ'],
  #   '{0}__{1}'.format('info', 'iregex'): filters['info'],
  # }


  # test_failure_filters {
  #   '{0}__{1}'.format('test_name', 'iregex'): filters['test_name'],
  #   '{0}__{1}'.format('test_variant', 'iregex'): filters['test_variant'],
  #   '{0}__{1}'.format('info_text', 'iregex'): filters['info_text'],
  #   '{0}__{1}'.format('failure_text', 'iregex'): filters['failure_text'],
  # }

  # Person.objects.filter(**kwargs)
  # test_failures = TestFailure.objects.all()

  # builders = Builders.objects.all()
  # test_runs = TestRun.objects.filter()


  # return rows
  return result
