FROM ruby:3

# Install SDL
RUN git clone --depth 1 https://github.com/libsdl-org/SDL-1.2.git /sdl
WORKDIR /sdl
RUN ./configure && make && make install

# Install SDL Image
RUN git clone --depth 1 --branch SDL-1.2 https://github.com/libsdl-org/SDL_image.git /sdl-image
WORKDIR /sdl-image
RUN ./configure && make && make install

COPY Gemfile /eevee/Gemfile

WORKDIR /eevee

# Install ruby gems
RUN bundle install && \
    gem install rubysdl -- --enable-bundled-sge

COPY . /eevee

WORKDIR /app
