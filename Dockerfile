FROM node as build

ARG LDC_VERSION=1.7.0

WORKDIR /src
RUN curl -fsS https://dlang.org/install.sh | bash -s ldc-$LDC_VERSION
# initial cache for node_modules
COPY frontend/package.json frontend/package-lock.json /src/frontend/
RUN cd frontend && npm install
COPY . /src/

CMD ["./dist.sh"]
