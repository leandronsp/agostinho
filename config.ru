require 'json'

require 'pg'
require 'connection_pool'

require 'chespirito'
require 'adelnor'

require_relative 'lib/accounts_service'

class AccountsController < Chespirito::Controller
  VALIDATION_ERRORS = [
    PG::InvalidTextRepresentation,
    PG::StringDataRightTruncation,
    AccountsService::InvalidLimitAmountError,
    AccountsService::InvalidDataError,
  ].freeze

  def bank_statement 
    account_id = request.params['account_id']
    service = AccountsService.new

    response.body = service.bank_statement(account_id).to_json
    response.status = 200
    response.headers['Content-Type'] = 'application/json'
  rescue PG::ForeignKeyViolation
    response.status = 404
  end

  def create_transaction 
    account_id = request.params['account_id']
    amount = request.params['valor']
    transaction_type = request.params['tipo']
    description = request.params['descricao']

    service = AccountsService.new
    result  = service.create_transaction(account_id, amount, 
                               transaction_type, description)

    response.body = result.to_json
    response.status = 200
    response.headers['Content-Type'] = 'application/json'
  rescue PG::ForeignKeyViolation
    response.status = 404
  rescue *VALIDATION_ERRORS
    response.status = 422
  end
end

RinhaApp = Chespirito::App.configure do |app|
  app.register_route('GET', '/clientes/:account_id/extrato', 
                     [AccountsController, :bank_statement])
  app.register_route('POST', '/clientes/:account_id/transacoes', 
                     [AccountsController, :create_transaction])
end

Adelnor::Server.run RinhaApp, 3000, thread_pool: 5
