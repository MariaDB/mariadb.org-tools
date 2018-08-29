import requests
import json
from bs4 import BeautifulSoup # To get everything
from selenium import webdriver
import time

def getData(URL):
        with requests.session() as client:
            responseGet = client.get(URL)
            return responseGet                            

versionWithGalera = ["10.2.3","10.2.6",
                     "10.1.20","10.1.22","10.1.30","10.1.32","10.1.33"]
# "10.1.21","10.1.23","10.1.24","10.1.25","10.1.28","10.1.29","10.1.31"

URL='https://downloads.mariadb.org/mariadb/+releases/'
# Get all data
response = getData(URL)
soup = BeautifulSoup(response.text,'html.parser')
# Get all names  
all_names = soup.find_all('h2')
# Get all tables are Tag not ResultSet(list)
all_tables=soup.findAll('table',class_='table table-bordered')

counter = 0; # counter = 0/1/2/3/4/5/6/7 (10.3/10.2/10.1/10.0/5.5/5.3/5.2/5.1)
data = {}
home="https://downloads.mariadb.org/"

for name in all_names[1:]: # skip the first name
        if(counter<100): 
                print(name.text)
                data[name.text]=[]
                currenttable = all_tables[counter]
                tr = currenttable.findAll("tr")
                for td in tr:
                        cell = td.findAll("td",attrs={'colspan':None})
                        if cell:
                                url = home+cell[0].find('a')['href']
                                version = url.split('/')[len(url.split('/')) - 2]
                                print(version)
                                i = len(versionWithGalera)-1
                                while i>=0:
                                        withGalera=False;
                                        if version==versionWithGalera[i]:
                                                withGalera=True;
                                                break
                                        i=i-1;
                                
                                driver = webdriver.Firefox()
                                driver.get(url)
                                time.sleep(4)
                                soup1 = BeautifulSoup(driver.page_source, 'html.parser')
                                table = soup1.find('table',class_='table table-bordered')
                                tr_all = table.findAll('tr');
                                if(withGalera==False):
                                        source_name = tr_all[1].findAll('td')[0].text.strip()
                                        source_size = tr_all[1].findAll('td')[3].text.strip()
                                        # Get the meta data
                                        if(version!="5.2.1"): # no checksum
                                                driver.find_element_by_css_selector('.btn.btn-mini.chksumlink').click()
                                                checksum = soup1.find('table',class_='table table-bordered').findAll('tr')[2].findAll('td')[0]
                                else:
                                        source_name = tr_all[4].findAll('td', class_='filename')[0].text.strip()
                                        source_size = tr_all[4].findAll('td')[3].text.strip()
#                                       # Get the meta data
                                        driver.find_element_by_css_selector('.btn.btn-mini.chksumlink').click()
                                        checksum = soup1.find('table',class_='table table-bordered').findAll('tr')[5].findAll('td')[0]

                                meta = checksum.text.split('-')[0].split('\n')
                                if(len(meta)>=3):
                                        sha256 = meta[2]
                                else:
                                        sha256=""
                                data[name.text].append({
                                        "name": cell[0].find(text=True),
                                        "release date": cell[1].find(text=True),
                                        "release status": cell[2].find(text=True),
                                        "link": url,
                                        "source":{
                                        "filename": source_name, # dynamic content javascript
                                        "file size": source_size,
                                        "sha256:": sha256
                                           }
                                        })
                                print(data[name.text])
                                #driver.close()
                                driver.quit() # will close geckodriver
                        
        counter+=1
                
print(data)
with open('data1.txt', mode='w') as f:
        f.write(json.dumps(data, indent=2))
with open('data.txt', 'w') as outfile:  
    json.dump(data,outfile)

        
