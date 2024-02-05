# agostinho
Uma versão Ruby bastante modesta da rinha de backend 2ª edição 2024/Q1

## First things first

```bash
make bundle.install
make start.dev
```

## Testando

```bash
curl http://localhost:9999/clientes/42/extrato

{
  "saldo": {
    "total": -9098,
    "data_extrato": "2024-01-17T02:34:41.217753Z",
    "limite": 100000
  },
  "ultimas_transacoes": [
    {
      "valor": 10,
      "tipo": "c",
      "descricao": "descricao",
      "realizada_em": "2024-01-17T02:34:38.543030Z"
    },
    {
      "valor": 90000,
      "tipo": "d",
      "descricao": "descricao",
      "realizada_em": "2024-01-17T02:34:38.543030Z"
    }
  ]
}
```

```bash
curl -X POST -d '{
    "valor": 1000,
    "tipo" : "c",
    "descricao" : "descricao"
}' http://localhost:9999/clientes/42/transacoes

{"limite":100000,"saldo":-9098}
```
