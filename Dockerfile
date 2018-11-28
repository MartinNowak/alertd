FROM node:10-jessie

ARG LDC_VERSION=1.12.0

WORKDIR /src
RUN curl -fsS https://dlang.org/install.sh | bash -s ldc-$LDC_VERSION
# initial cache for node_modules
COPY frontend/package.json frontend/yarn.lock /src/frontend/
RUN npm install -g yarn
RUN cd frontend && yarn install
COPY . /src/

CMD ["./dist.sh"]
