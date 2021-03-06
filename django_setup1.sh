#!/bin/sh

#let the user choose where they want to start
echo "1. Create Virtual Env\n2. Create Django Project\n3. Reorganize Settings Folder\nType the number of what you'd like to start from followed by [ENTER]:"
read choice

#create environment
if [ $choice -eq 1 ]; then
  echo "Environment Name:"
  read envname
  echo "Python Version:"
  read pythver
  conda create -n $envname python=$pythver django
  source activate $envname
fi

#create django project
if [[ $choice -eq 1 || $choice -eq 2 ]]; then
  echo "Project Name:"
  read projname
  django-admin startproject $projname
  cd $projname
  python manage.py migrate
  python manage.py createsuperuser
  cd $projname
fi

#create the new settings file structure
if [[ $choice -eq 1 || $choice -eq 2 || $choice -eq 3 ]]; then
  #change BASE_DIR to reflect the new settings module we're about to create
  sed -e 's/BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))/BASE_DIR = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))/' settings.py > temp_file.py
  mv temp_file.py settings.py
  #create the settings folder
  mkdir settings
  #move settings.py into new settings module and rename to base.py
  mv settings.py settings/base.py
  # add module initialization
  cd settings
  echo "from .base import *
  #from .production import *
  #try:
  #   from .local import *
  #except:
  #   pass
  " > __init__.py

  #Copy Local settings (local.py) to make new (base.py & production.py) file:
  cp base.py production.py

  #add production code to top of production.py file
  echo "CORS_REPLACE_HTTPS_REFERER      = True
  HOST_SCHEME                     = 'https://'
  SECURE_PROXY_SSL_HEADER         = ('HTTP_X_FORWARDED_PROTO', 'https')
  SECURE_SSL_REDIRECT             = True
  SESSION_COOKIE_SECURE           = True
  CSRF_COOKIE_SECURE              = True
  SECURE_HSTS_INCLUDE_SUBDOMAINS  = True
  SECURE_HSTS_SECONDS             = 1000000
  SECURE_FRAME_DENY               = True\n\n" | cat - production.py > temp && mv temp production.py


  #add base code to top of base.py file and make copy called local.py
  echo "CORS_REPLACE_HTTPS_REFERER      = False
  HOST_SCHEME                     = 'http://'
  SECURE_PROXY_SSL_HEADER         = None
  SECURE_SSL_REDIRECT             = False
  SESSION_COOKIE_SECURE           = False
  CSRF_COOKIE_SECURE              = False
  SECURE_HSTS_SECONDS             = None
  SECURE_HSTS_INCLUDE_SUBDOMAINS  = False
  SECURE_FRAME_DENY               = False\n\n" | cat - base.py > temp && mv temp base.py && cp base.py local.py


  #add code to production.py for heroku database to work
  DATABASE_REPLACE="DATABASES = {\n    \'default\': {\n        \'ENGINE\': \'django.db.backends.sqlite3\',\n        \'NAME\': os.path.join\(BASE_DIR, \'db.sqlite3\'\),\n    }\n}\n"
  DATABASE_STR="import dj_database_url\ndb_from_env = dj_database_url.config()\nDATABASES[\'default\'].update(db_from_env)\nDATABASES[\'default\'][\'CONN_MAX_AGE\'] = 500\n"

  #perl script
  perl -i -0pe "s/$DATABASE_REPLACE/$DATABASE_REPLACE\n$DATABASE_STR/" production.py
fi
