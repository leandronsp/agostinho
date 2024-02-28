require_relative 'database_adapter'

class AccountsService
  class InvalidLimitAmountError < StandardError; end
  class InvalidDataError < StandardError; end

  def bank_statement(account_id)
    result = {}

    DatabaseAdapter.pool.with do |conn|
      sql = <<~SQL
        SELECT 
          limit_amount,
          balance
        FROM accounts
        WHERE id = $1
      SQL

      query_result = conn.exec_params(sql, [account_id]).first
      raise PG::ForeignKeyViolation unless query_result

      result["saldo"] = {  
        "total": query_result['balance'].to_i,
        "data_extrato": Time.now.strftime("%Y-%m-%d"),
        "limite": query_result['limit_amount'].to_i
      }

      sql = <<~SQL
        SELECT 
          amount, 
          transaction_type, 
          description, 
          TO_CHAR(date, 'YYYY-MM-DD HH:MI:SS.US') AS date
        FROM transactions
        WHERE transactions.account_id = $1
        ORDER BY date DESC
        LIMIT 10
      SQL

      query_result = conn.exec_params(sql, [account_id])

      result["ultimas_transacoes"] = query_result.map do |transaction|
        { 
          "valor": transaction['amount'].to_i,
          "tipo": transaction['transaction_type'],
          "descricao": transaction['description'],
          "realizada_em": transaction['date']
        }
      end
    end

    result
  end

  def create_transaction(account_id, amount, transaction_type, description)
    result = {}

    raise InvalidDataError unless account_id && amount && transaction_type && description
    raise InvalidDataError unless %w[d c].include?(transaction_type)
    raise InvalidDataError if description && description.empty?
    raise InvalidDataError if description && description.size > 10
    raise InvalidDataError if amount && (!amount.is_a?(Integer) || !amount.positive?)

    DatabaseAdapter.pool.with do |conn|
      conn.transaction do
        sql = <<~SQL
          SELECT 
            limit_amount,
            balance
          FROM accounts
          WHERE id = $1
          FOR UPDATE
        SQL

        query_result = conn.exec_params(sql, [account_id]).first

        raise PG::ForeignKeyViolation unless query_result

        if transaction_type == 'd' && reaching_limit?(query_result['balance'].to_i, 
                                                      query_result['limit_amount'].to_i, 
                                                      amount.to_i)
          raise InvalidLimitAmountError 
        end

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
            UPDATE accounts 
            SET balance = balance - $2
            WHERE id = $1
          SQL
        in 'c'
          sql = <<~SQL
            UPDATE accounts 
            SET balance = balance + $2
            WHERE id = $1
          SQL
        end
        
        conn.exec_params(sql, [account_id, amount])

        sql = <<~SQL
          SELECT 
            limit_amount,
            balance
          FROM accounts
          WHERE id = $1
          FOR UPDATE
        SQL

        query_result = conn.exec_params(sql, [account_id]).first

        result.merge!({ 
          limite: query_result['limit_amount'].to_i,
          saldo: query_result['balance'].to_i
        })
      end
    end

    result
  end

  private

  def reaching_limit?(balance, limit_amount, amount)
    return false if (balance - amount) > limit_amount
    (balance - amount).abs > limit_amount
  end
end
