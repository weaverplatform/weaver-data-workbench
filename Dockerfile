FROM node:0.12

# Docker nodejs creation following 
# https://nodejs.org/en/docs/guides/nodejs-docker-webapp/

RUN apt-get update && apt-get install -y netcat
RUN npm install -g bower grunt

RUN mkdir -p /usr/src/app
WORKDIR /usr/src/app

COPY code /usr/src/app
RUN npm install --quiet
RUN bower --allow-root install

EXPOSE 9010

CMD sleep 3 && echo 'Waiting for weaver-server ' && while ! nc -w 1 -z ${WEAVER_HOST} ${WEAVER_PORT}; do sleep 0.1; done && grunt
