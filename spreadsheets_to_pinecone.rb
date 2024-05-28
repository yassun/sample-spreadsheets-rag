require 'bundler'
Bundler.require

Dotenv.load

# コマンドライン引数からファイル名とシート名を取得
spreadsheets_name = ARGV[0]
sheets_name       = ARGV[1]

# スプレッドシートからJSON形式でデータを取得
connection = Faraday.new("https://sheets.googleapis.com/v4/spreadsheets/#{spreadsheets_name}/values/") do |builder|
  builder.request :url_encoded
  builder.response :json
  builder.adapter Faraday.default_adapter
end
connection.params[:key] = ENV.fetch('GOOGLE_SPREADSHEETS_API_KEY')
res = connection.get(sheets_name)

# Pineconeに登録するデータを作成
OpenAI.configure do |config|
  config.access_token = ENV.fetch('OPENAI_ACCESS_TOKEN')
  config.organization_id = ENV.fetch('OPENAI_ORGANIZATION_ID') # Optional
end
open_ai = OpenAI::Client.new

vectors = []
res.body['values'].each_with_index do |row, i|
  question = row[0].gsub(/\R/, ' ')
  answer = row[1].gsub(/\R/, ' ')
  vector = open_ai.embeddings(
    parameters: { input: question, model: 'text-embedding-ada-002' }
  ).dig('data', 0, 'embedding')

  vectors << {
    id: "#{spreadsheets_name}_#{sheets_name}_#{i}",
    metadata: {
      file: spreadsheets_name,
      sheet: sheets_name,
      question: question,
      answer: answer
    },
    values: vector
  }
end

## Pineconeにデータを登録
Pinecone.configure do |config|
  config.api_key = ENV.fetch('PINECONE_API_KEY')
  config.environment = ENV.fetch('PINECONE_ENVIRONMENT')
end

pinecone = Pinecone::Client.new
pinecone_index = pinecone.index('sample-index')
pp pinecone_index.upsert(
  namespace: 'example-namespace',
  vectors: vectors
)
