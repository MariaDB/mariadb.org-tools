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


def select_test_failures(filters, include_failures=True):
  available_filters = ["branch", "revision", "platform", "dt", "bbnum", "typ", "info", "test_name", "test_variant", "info_text", "failure_text"]

  # New implementation
  limit = 5
  if 'limit' in filters and filters['limit'] != '':
    limit = int(filters['limit'])

  test_run_filters = None
  test_failure_filters = None

  reg_exp = {
    'branch': [
      # Pattern: 10.?
      {
        'pattern': '^([0-9]{1,2}\.)(\?)$',
        'filter': [('test_run_id__branch__startswith', 'AND')],
        'replace': True
      },
      # Pattern: 10.1, 10.2, 5.5...
      {
        'pattern': '^([0-9]{1,2}\.)([0-9]{1,2})$',
        'filter': [('test_run_id__branch__exact', 'AND')],
        'replace': False
      },
      # Pattern: *10.1*, *10.2*...
      {
        'pattern': '^\*([0-9]{1,2}\.)([0-9]{1,2})\*$',
        'filter': [('test_run_id__branch__icontains', 'AND')],
        'replace': True
      },
      # Pattern *10.?*
      {
        'pattern': '^\*([0-9]{1,2}\.)(\?)\*$',
        'filter': [('test_run_id__branch__icontains', 'AND'), ('test_run_id__branch__startswith', 'OR')],
        'replace': True
      },
      {
        'pattern': '^[a-zA-Z0-9_.-]*$',
        'filter': [('test_run_id__branch__icontains', 'AND')],
        'replace': False
      }
    ],
    'revision': [
      {
        'pattern': '^[a-zA-Z0-9]*$',
        'filter': [('test_run_id__revision__startswith', 'AND')],
        'replace': False
      }
    ],
    'platform': [
      {
        'pattern': '^[a-zA-Z0-9_.-]*$',
        'filter': [('test_run_id__platform__exact', 'AND')],
        'replace': False
      },
      {
        'pattern': '^\*[a-zA-Z0-9_.-]*\*$',
        'filter': [('test_run_id__platform__icontains', 'AND')],
        'replace': True
      }
    ],
    'typ': [
      {
        'pattern': '^[a-zA-Z0-9]*$',
        'filter': [('test_run_id__typ__exact', 'AND')],
        'replace': False
      },
      {
        'pattern': '^[a-zA-Z0-9]*\*$',
        'filter': [('test_run_id__typ__startswith', 'AND')],
        'replace': True
      }
    ],
    'info': [
      {
        'pattern': '^[a-zA-Z0-9]*$',
        'filter': [('test_run_id__info__exact', 'AND')],
        'replace': False
      },
      {
        'pattern': '^[a-zA-Z0-9]*\*$',
        'filter': [('test_run_id__info__startswith', 'AND')],
        'replace': True
      }
    ],
    'test_name': [
      {
        'pattern': '^[a-zA-Z0-9_.-]*$',
        'filter': [('test_name__exact', 'AND')],
        'replace': False
      },
      {
        'pattern': '^\*\.[a-zA-Z0-9_.-]*$',
        'filter': [('test_name__icontains', 'AND')],
        'replace': True
      }
    ],
    'test_variant': [
      {
        'pattern': '^[a-zA-Z0-9]*$',
        'filter': [('test_variant__exact', 'AND')],
        'replace': False
      },
      {
        'pattern': '^\*[a-zA-Z0-9]*\*$',
        'filter': [('test_variant__in', 'AND')],
        'replace': True
      }
    ],
    'failure_text': [
      {
        'pattern': '^timeout$',
        'filter': [('failure_text__icontains', 'AND')],
        'replace': False
      },
      {
        'pattern': '^\*[a-zA-Z0-9]*\*$',
        'filter': [('failure_text__icontains', 'AND')],
        'replace': True
      }
    ],

  }

  # Loop each dropdown input
  for key in filters:
    if filters[key] and key in available_filters:
      match = None
      search_string = filters[key]
      q_objects = Q()

      # If the dropdown is found in the Regex rule dict
      if key in reg_exp:
        # Loop through each possible Regex pattern until one matches
        for expression in reg_exp[key]:
          # Try matching the Regex pattern with the input of the dropdown
          match = re.search(expression['pattern'], filters[key])
          if match is None:
            continue

          # If the input contains ? or * then eliminate them
          # This is the case for multiple Regex rules. Example: 10.?, *timeout* etc.
          if expression['replace']:
            search_string = re.sub('(\?)|(\*)', '', search_string)

          # Loop through all the filters of a pattern
          # The filters are used for the database columns
          for f in expression['filter']:
            # Filtering columns is done through Q objects
            if f[1] == 'OR':
              q_objects |= Q(**{f[0]: search_string})
            else:
              q_objects &= Q(**{f[0]: search_string})

            break

        # If the Q object is empty then skip to the next dropdown input
        # Without this check, it pulls random results
        if not len(q_objects):
          continue

        # If it's the first time filtering, then query the database model
        # Otherwise use the variable to continue filtering
        if test_failure_filters is not None:
          test_failure_filters = test_failure_filters.filter(q_objects)
        else:
          test_failure_filters = TestFailure.objects.filter(q_objects)

  # From Date dropdown filtering
  if filters['dt']:
    # Check 2 date and time formats (one with time, another without)
    for dt_format in ('%Y-%m-%d', '%Y-%m-%d %H:%M:%S'):
      try:
        formatted_date = datetime.strptime(filters['dt'], dt_format)
      except ValueError as e:
        print(e)
        pass
      # Include the date in filtering if the passes the try/except block
      else:
        if test_failure_filters is not None:
          test_failure_filters = test_failure_filters.filter(Q(test_run_id__dt__gte=formatted_date))
        else:
          test_failure_filters = TestFailure.objects.filter(Q(test_run_id__dt__gte=formatted_date))

  # Apply the limit filer and get related models to limit the no. of queries
  if test_failure_filters is not None:
    test_failure_filters = test_failure_filters[0:limit]
    test_failure_filters = test_failure_filters.select_related('test_run_id')


  result = {
    'test_runs': test_failure_filters,
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
