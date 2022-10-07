FROM ruby:3

RUN gem install parallel

COPY . /eevee

WORKDIR /app

ENTRYPOINT ["ruby", "/eevee/eevee.rb"]

