require 'json'

require 'chespirito'
require 'adelnor'
require 'puma'
require 'rack/handler/puma'

require_relative 'database_adapter'

class AccountsController < Chespirito::Controller
  class InvalidLimitAmountError < StandardError; end
  class InvalidDataError < StandardError; end

  def bank_statement 
    result = {}
    account_id = request.params['account_id']

    conn = DatabaseAdapter.pool.checkout

    conn.transaction do
      sql = <<~SQL
        SELECT accounts.id AS account_id, balances.amount AS amount, accounts.limit_amount AS limit_amount
        FROM accounts 
        JOIN balances ON balances.account_id = accounts.id
        WHERE accounts.id = $1
        FOR UPDATE
      SQL

      query_result = conn.exec_params(sql, [account_id]).first

      raise PG::ForeignKeyViolation unless query_result

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
        FOR UPDATE
      SQL

      query_result = conn.exec_params(sql, [account_id])

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
  rescue PG::ForeignKeyViolation
    response.status = 404
  end

  def create_transaction 
    account_id = request.params['account_id']
    amount = request.params['valor']
    transaction_type = request.params['tipo']
    description = request.params['descricao']

    raise InvalidDataError unless account_id && amount && transaction_type && description
    raise InvalidDataError if description && description.empty?

    conn = DatabaseAdapter.pool.checkout

    conn.transaction do
      sql = <<~SQL
        SELECT accounts.id AS account_id, balances.amount AS amount, accounts.limit_amount AS limit_amount
        FROM accounts 
        JOIN balances ON balances.account_id = accounts.id
        WHERE accounts.id = $1
        FOR UPDATE
      SQL

      query_result = conn.exec_params(sql, [account_id]).first

      raise PG::ForeignKeyViolation unless query_result
      raise InvalidLimitAmountError if transaction_type == 'd' && (query_result['amount'].to_i - amount).abs > query_result['limit_amount'].to_i

      sql = <<~SQL
        INSERT INTO transactions (account_id, amount, transaction_type, description)
        VALUES ($1, $2, $3, $4)
      SQL

      conn.exec_params(sql, 
        [account_id, amount, transaction_type, description],
      )

      raise InvalidDataError unless %w[d c].include?(transaction_type)

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
      
      conn.exec_params(sql, [account_id, amount])

      sql = <<~SQL
        SELECT accounts.id AS account_id, balances.amount AS amount, accounts.limit_amount AS limit_amount
        FROM accounts 
        JOIN balances ON balances.account_id = accounts.id
        WHERE accounts.id = $1
        FOR UPDATE
      SQL

      result = conn.exec_params(sql, [account_id]).first

      response.body = { 
        limite: result['limit_amount'],
        saldo: result['amount']
      }.to_json

      response.status = 200
      response.headers['Content-Type'] = 'application/json'
    end
  rescue PG::ForeignKeyViolation
    response.status = 404
  rescue InvalidLimitAmountError, PG::InvalidTextRepresentation, InvalidDataError, PG::StringDataRightTruncation
    response.status = 422
  end
end

RinhaApp = Chespirito::App.configure do |app|
  app.register_route('GET', '/clientes/:account_id/extrato', [AccountsController, :bank_statement])
  app.register_route('POST', '/clientes/:account_id/transacoes', [AccountsController, :create_transaction])
end

#Rack::Handler::Puma.run RinhaApp, Port: 3000, Threads: '0:5'
Adelnor::Server.run RinhaApp, 3000, thread_pool: 5
