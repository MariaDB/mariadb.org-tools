#!/usr/bin/env python3
import zulip
import sys
from datetime import datetime
import time
import requests
import json
from bs4 import BeautifulSoup # To get everything
from selenium import webdriver

def request_data(client, num_before, data_planet):
  # Request is always done based on the latest entry
  # First try dummy request (since there is no API for time_date as a parameter):
    # Get 10 blogs before, check the date.
    # If returned date is greater than last weeek(`current_date - number_of_days`) accept it
    # If returned date is less than last week increase number of `num_before`
  request_planet={"anchor":"newest", "num_before":num_before, "num_after": 0, "narrow": data_planet}
  res_planet=client.get_messages(request_planet)
  if(res_planet['result'] == 'error'):
    print("Error in getting data: \n",res_planet['code'])
    sys.exit()

  end_date= res_planet['messages'][len(res_planet['messages'])-1]['timestamp']
  start_date= res_planet['messages'][0]['timestamp']
  converted_end_date= datetime.fromtimestamp(end_date)
  converted_start_date = datetime.fromtimestamp(start_date)

  # Check converted_start_date - current_date days
  today= datetime.fromtimestamp(time.time())
  delta= today - converted_start_date # returns days,seconds,..

  calculate_days= delta.days
  if (calculate_days < 0):
    print ("Start date",converted_start_date,"of search is greater of current date", today)
    sys.exit()
  return calculate_days, res_planet

def getData(URL):
        with requests.session() as client:
            responseGet = client.get(URL)
            return responseGet

def scrap_blogs(ret):
  blogs_count={}
  for i in range(len(ret['messages'])-1):
    if not 'blogs' in blogs_count:
      blogs_count['blogs']=0
      blogs_count['count']=0
      blogs_count['blogs_with_maria']=0
    else:
      blogs_count['blogs']+=1
    soup = BeautifulSoup(ret['messages'][i]['content'],'html.parser')
    url= soup.find('a')['href']
    response = getData(url)
    if(response.status_code == 200):
      soup = BeautifulSoup(response.text,'html.parser')
      text = soup.get_text().lower()
      if text.count('maria') > 0:
	      blogs_count['count']+=text.count('maria')
	      blogs_count['blogs_with_maria']+=1

  return blogs_count
    

def main():
  # Pass the path to your zuliprc file here.
  client = zulip.Client(config_file="./zulip.rc")

  number_of_days= 14 # specify number of days you want blogs from
  num_of_blogs_before= 10
  calculate_days= 0
  i=0

  data_planet=[
    {
      "operator": "stream",
      "operand": "general"
    },
    {
      "operator": "topic",
      "operand": "PlanetMariaDB"
    },
    #{
      #"operator": "search",
      #"operand": "maria" #case-insensitive
    #}
  ]
  while (calculate_days < number_of_days):
    print ("Scrapping phase: ",i)
    i+=1
    calculate_days, ret_message= request_data(client, num_of_blogs_before, data_planet)
    num_of_blogs_before+=10
  if (len(ret_message['messages'])):
    blogs_count= scrap_blogs(ret_message)
    print ("--- Statistic during the last ",number_of_days," days ---\nTotal number of blogs: ",blogs_count['blogs'],\
           "\nNumber of blogs referrencing Maria: ",blogs_count['blogs_with_maria'],\
           "\nNumber of blogs not referrencing Maria: ",blogs_count['blogs'] - blogs_count['blogs_with_maria'],\
           "\nCounter of referrencing Maria: ",blogs_count['count'],\
           "\n------------------- END -------------------")

if __name__ == "__main__":
    main()

# Useful links:
# https://zulipchat.com/api/get-messages
# https://zulipchat.com/api/construct-narrow