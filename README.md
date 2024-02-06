# agostinho

```
   __    ___  _____  ___  ____  ____  _  _  _   _  _____ 
  /__\  / __)(  _  )/ __)(_  _)(_  _)( \( )( )_( )(  _  )
 /(__)\( (_-. )(_)( \__ \  )(   _)(_  )  (  ) _ (  )(_)( 
(__)(__)\___/(_____)(___/ (__) (____)(_)\_)(_) (_)(_____)
```

Uma versão Ruby bastante modesta da [rinha do backend 2ª edição](https://github.com/zanfranceschi/rinha-de-backend-2024-q1) 2024/Q1

## Requisitos

* [Docker](https://docs.docker.com/get-docker/)
* [Gatling](https://gatling.io/open-source/), a performance testing tool
* Make (optional)

## Stack

* 2 Ruby 3.3 [+YJIT](https://shopify.engineering/ruby-yjit-is-production-ready) apps
* 1 PostgreSQL
* 1 NGINX

## Ruby é lento????? So far, so good
<img width="1028" alt="Screenshot 2024-02-06 at 18 35 51" src="https://github.com/leandronsp/agostinho/assets/385640/a5cb5a00-50af-46ec-a781-435333ebe553">

## Usage

```bash
$ make help

Usage: make <target>
  help                       Prints available commands
  start.dev                  Start the rinha in Dev
  start.prod                 Start the rinha in Prod
  docker.stats               Show docker stats
  health.check               Check the stack is healthy
  stress.it                  Run stress tests
  docker.build               Build the docker image
  docker.push                Push the docker image
```

## Inicializando a aplicação

```bash
$ docker compose up -d nginx

# Ou então utilizando Make...
$ make start.dev
```

Testando a app:

```bash
$ curl -v http://localhost:9999/clientes/1/extrato

# Ou então utilizando Make...
$ make health.check
```

## Unleash the madness

Colocando Gatling no barulho:

```bash
$ make stress.it 
$ open stress-test/user-files/results/**/index.html
```

----

[ASCII art generator](http://www.network-science.de/ascii/)
