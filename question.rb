require 'bundler'
Bundler.require

Dotenv.load

# コマンドライン引数から質問を取得
text = ARGV[0]

# OpenAI
OpenAI.configure do |config|
  config.access_token = ENV.fetch('OPENAI_ACCESS_TOKEN')
  config.organization_id = ENV.fetch('OPENAI_ORGANIZATION_ID')
end
open_ai = OpenAI::Client.new

# Pinecone
Pinecone.configure do |config|
  config.api_key = ENV.fetch('PINECONE_API_KEY')
  config.environment = ENV.fetch('PINECONE_ENVIRONMENT')
end
pinecone = Pinecone::Client.new
index = pinecone.index('sample-index')

# 質問内容をvectorにする
vector = open_ai.embeddings(
  parameters: { input: text, model: 'text-embedding-ada-002' }
).dig('data', 0, 'embedding')

# Pineconeから検索結果を10件取得する
res = index.query(
  vector: vector,
  namespace: 'example-namespace',
  top_k: 10,
  include_values: false,
  include_metadata: true
)

# 取得結果からプロンプトを作成する
list = res['matches'].map do
  "質問: #{_1['metadata']['question']}, 回答: #{_1['metadata']['answer']}"
end.join("\n")

question = <<~EOS
  #命令書:
  あなたは、情報セキュリティ責任者です。
  以下の制約条件と過去の回答をもとに、質問に対する回答を出力してください。

  #制約条件:
  ・文字数は 100文字以内

  #過去の回答:
  #{list}

  #質問:
  #{text}

  #出力文:
EOS

# ChatGPTに問い合わせる
response = open_ai.chat(
  parameters: {
    model: 'gpt-4o',
    messages: [{ role: 'user', content: question }]
  }
)
puts response.dig('choices', 0, 'message', 'content')
