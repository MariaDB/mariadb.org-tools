from django.db import models, connections

# Create your models here.
def select_test_failures(filters, include_failures=True):
    available_filters = ["branch", "revision", "platform", "dt", "bbnum", "typ", "info", "test_name", "test_variant", "info_text", "failure_text"]
    with connections['buildbot'].cursor() as cursor:
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

    return rows

