from django.contrib import admin
from cr.models import Builders, TestFailure, TestRun

admin.site.register(Builders)
admin.site.register(TestFailure)
admin.site.register(TestRun)
# Register your models here.
