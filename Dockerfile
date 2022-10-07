FROM ruby:3-alpine

RUN gem install parallel

COPY . /eevee

WORKDIR /app

ENTRYPOINT ["ruby", "/eevee/eevee.rb"]

