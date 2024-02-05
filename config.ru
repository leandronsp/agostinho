require 'json'

require 'chespirito'
require 'adelnor'

require 'pg'

#require_relative 'app/people_repository'
#require_relative 'app/person_serializer'

class AccountsController < Chespirito::Controller
  PG_EXCEPTIONS = [
    PG::StringDataRightTruncation,
    PG::InvalidDatetimeFormat,
    PG::DatetimeFieldOverflow,
    PG::NotNullViolation,
    PG::UniqueViolation,
  ].freeze

  def bank_statement 
    response.body = File.read('extrato.json')
    response.status = 200
    response.headers['Content-Type'] = 'application/json'
  end

  def create_transaction 
    response.body = { 
      limite: 100_000,
      saldo: -9098
    }.to_json

    response.status = 200
    response.headers['Content-Type'] = 'application/json'
  end
end

RinhaApp = Chespirito::App.configure do |app|
  app.register_route('GET', '/clientes/:id/extrato', [AccountsController, :bank_statement])
  app.register_route('POST', '/clientes/:id/transacoes', [AccountsController, :create_transaction])
end

Adelnor::Server.run RinhaApp, 3000, thread_pool: 5
