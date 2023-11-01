FROM ruby:3

# Install SDL
RUN git clone https://github.com/libsdl-org/SDL-1.2.git /sdl
WORKDIR /sdl
RUN ./configure && make && make install

# Install SDL Image
ADD https://github.com/libsdl-org/SDL_image/archive/refs/tags/release-1.2.12.zip /tmp
WORKDIR /sdl-image
RUN unzip /tmp/release-1.2.12.zip && \
    mv SDL_image-release-1.2.12/* . && \
    rm -r SDL_image-release-1.2.12
RUN ./configure && make && make install

# Install ruby gems
RUN gem install rubysdl -- --enable-bundled-sge && \
    gem install parallel

COPY . /eevee

WORKDIR /app
