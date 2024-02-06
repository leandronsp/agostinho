require 'json'

require 'chespirito'
require 'adelnor'

require_relative 'database_adapter'

class AccountsController < Chespirito::Controller
  def bank_statement 
    result = {}
    account_id = request.params['account_id']

    sql = <<~SQL
      SELECT accounts.id AS account_id, balances.amount AS amount, accounts.limit_amount AS limit_amount
      FROM accounts 
      JOIN balances ON balances.account_id = accounts.id
      WHERE accounts.id = $1
    SQL

    query_result = execute_with_params(sql, [account_id]).first

    result["saldo"] = {  
      "total": query_result['amount'],
      "data_extrato": Time.now.strftime("%Y-%m-%d"),
      "limite": query_result['limit_amount']
    }

    sql = <<~SQL
      SELECT amount, transaction_type, description, date
      FROM transactions
      WHERE transactions.account_id = $1
      ORDER BY date DESC
      LIMIT 10
    SQL

    query_result = execute_with_params(sql, [account_id])

    result["ultimas_transacoes"] = query_result.map do |transaction|
      { 
        "valor": transaction['amount'],
        "tipo": transaction['transaction_type'],
        "descricao": transaction['description'],
        "realizada_em": transaction['date']
      }
    end

    response.body = result.to_json
    response.status = 200
    response.headers['Content-Type'] = 'application/json'
  end

  def create_transaction 
    account_id = request.params['account_id']
    amount = request.params['valor']
    transaction_type = request.params['tipo']
    description = request.params['descricao']

    sql = <<~SQL
      INSERT INTO transactions (account_id, amount, transaction_type, description)
      VALUES ($1, $2, $3, $4)
    SQL

    execute_with_params(sql, 
      [account_id, amount, transaction_type, description],
    )

    case transaction_type
    in 'd'
      sql = <<~SQL
        UPDATE balances 
        SET amount = amount - $2
        WHERE account_id = $1
      SQL
    in 'c'
      sql = <<~SQL
        UPDATE balances 
        SET amount = amount + $2
        WHERE account_id = $1
      SQL
    end
    
    execute_with_params(sql, [account_id, amount])

    sql = <<~SQL
      SELECT accounts.id AS account_id, balances.amount AS amount, accounts.limit_amount AS limit_amount
      FROM accounts 
      JOIN balances ON balances.account_id = accounts.id
      WHERE accounts.id = $1
    SQL

    result = execute_with_params(sql, [account_id]).first

    response.body = { 
      limite: result['limit_amount'],
      saldo: result['amount']
    }.to_json

    response.status = 200
    response.headers['Content-Type'] = 'application/json'
  end
  
  def execute_with_params(sql, params)
    DatabaseAdapter.pool.with do |conn|
      conn.exec_params(sql, params)
    end
  end
end

RinhaApp = Chespirito::App.configure do |app|
  app.register_route('GET', '/clientes/:account_id/extrato', [AccountsController, :bank_statement])
  app.register_route('POST', '/clientes/:account_id/transacoes', [AccountsController, :create_transaction])
end

Adelnor::Server.run RinhaApp, 3000, thread_pool: 5
