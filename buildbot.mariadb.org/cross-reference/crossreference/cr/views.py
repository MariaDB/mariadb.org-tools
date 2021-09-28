from django.shortcuts import render

# Create your views here.
from django.http import HttpResponse

from .models import select_test_failures

def index(request):
  available_filters = ["branch", "revision", "platform", "dt", "bbnum", "typ", "info", "test_name", "test_variant", "info_text", "failure_text", "limit"]

  if request.method == 'GET':
    qd = request.GET
  elif request.method == 'POST':
    qd = request.POST

  if qd == {}:
    return render(request, "cr/index.html", {})

  all_failures_list = select_test_failures(qd)

  context = all_failures_list

  for f in available_filters:
    if f in qd:
      context[f] = qd[f]

  return render(request, "cr/index.html", context)
