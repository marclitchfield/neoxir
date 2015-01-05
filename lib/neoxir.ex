defmodule Neoxir do

  defmodule Session do
    defstruct root_url: "", data_url: "", tx_end_point_url: "", root_resource: %{}
  end

  defmodule Transaction do
    defstruct commit_url: "", errors: [], expires: %{}
  end

  defmodule CypherResult do
    defstruct columns: [], rows: []
  end

  defmodule CypherResponse do
    defstruct status_code: 0, body: ""


    def to_rows(%CypherResponse{body: body}) do
      {:ok, r} = JSX.decode(body)
      result = r["results"]
      Enum.map(result, &(map_result(&1)))
    end

    defp map_result(result) do
      columns = Enum.map(result["columns"], &(String.to_atom(&1)))
      rows = rows(result["data"])
      IO.inspect rows
      Enum.map(rows, &(map_row(columns, &1)))
    end

    defp map_row(columns, row) do
      {result, _} = Enum.reduce(row, {%{}, columns}, fn value, {dict, [h|t]} -> {Dict.put(dict, h, value), t} end)
      result
    end

    defp rows(data) do
      Enum.map(data, fn %{"row" => row} -> row end)
    end

  end


  defmodule CypherError do
    defstruct code: "", message: ""
  end


  def commit(session, statements) do
    response = Neoxir.TxEndPoint.commit(session, statements)
    rows = CypherResponse.to_rows(response)
    {:ok, List.first(rows)}
  end

  def create_session(url \\ "http://localhost:7474/") do
    {:ok, data} = HTTPoison.get(url)
    {:ok, body} = JSX.decode(data.body)
    data_url = body["data"]

    {:ok, data} = HTTPoison.get(data_url)
    {:ok, body} = JSX.decode(data.body)

    # body
    %Session{root_url: url, data_url: data_url, root_resource: body, tx_end_point_url: body["transaction"]}
  end


  defmodule TxEndPoint do
    @headers %{"Accept" => "application/json; charset=UTF-8", "Content-Type" => "application/json"}

    # Begin and commit a transaction in one request
    # If there is no need to keep a transaction open across multiple HTTP requests, 
    # you can begin a transaction, execute statements, and commit with just a single HTTP request.
    def commit(%Session{tx_end_point_url: tx_end_point_url}, [head|_] = statements) when is_list head do
      {:ok, payload}  = JSX.encode statements: statements
      {:ok, response} = HTTPoison.post("#{tx_end_point_url}/commit", payload, @headers)
      # to_result = fn %{"columns" => columns, "data" => [%{"row" => rows}]} -> %CypherResult{columns: columns, row: rows} end
      # results = Enum.map(body["results"], to_result)

      # to_errors = fn %{"code" => code, "message" => message} -> %CypherError{code: code, message: message} end
      # errors = Enum.map(body["errors"], to_errors)

      # {:ok, body } = JSX.decode response.body

      %CypherResponse{status_code: response.status_code, body: response.body} # results: body["results"], errors: body["errors"]
    end

    def commit(session = %Session{}, statement) do 
      commit(session, [statement])
    end


    # Commit an open transaction
    # Given you have an open transaction, you can send a commit request. 
    # Optionally, you submit additional statements along with the request that will be executed before committing the transaction.
    def commitx(transaction, statements) do
    end

    # Begin a transaction
    # You begin a new transaction by posting zero or more Cypher statements to the transaction endpoint. 
    # The server will respond with the result of your statements, as well as the location of your open transaction.
    def begin_tx(%Session{tx_end_point_url: tx_end_point_url}, statements \\ []) do
      {:ok, payload}  = JSX.encode [statements: statements]
      {:ok, response} = HTTPoison.post(tx_end_point_url, payload, @headers)
      {:ok, body }    = JSX.decode response.body

      %Transaction{commit_url: body["commit"], errors: body["errors"], expires: body["transaction"]["expires"]}
    end

    # Execute statements in an open transaction
    # Given that you have an open transaction, you can make a number of requests, each of which executes additional statements,
    # and keeps the transaction open by resetting the transaction timeout.
    def execute(transaction, statements) do
    end


    # Execute statements in an open transaction in REST format for the return
    # Given that you have an open transaction, you can make a number of requests, each of which executes additional statements, and keeps the transaction open by resetting the transaction timeout. Specifying the REST format will give back full Neo4j Rest API representations of the Neo4j Nodes, Relationships and Paths, if returned.


    # Reset transaction timeout of an open transaction
    # Every orphaned transaction is automatically expired after a period of inactivity. This may be prevented by resetting the transaction timeout.
    # The timeout may be reset by sending a keep-alive request to the server that executes an empty list of statements. This request will reset the transaction timeout and return the new time at which the transaction will expire as an RFC1123 formatted timestamp value in the “transaction” section of the response.
    def reset(transaction) do
    end



    # Rollback an open transaction
    # Given that you have an open transaction, you can send a roll back request. The server will roll back the transaction.
    def rollback(transaction) do
    end

  end



  defmodule Node do
    def create do
      url = "http://localhost:7474/db/data/transaction/commit"
      body = """
        "statements" : [ {
          "statement" : "CREATE (n) RETURN id(n)"
        } ]
      """

      {:ok, b} = JSX.encode [statements: [statement: "CREATE (n) RETURN id(n)"]]

      HTTPoison.post(url, b, %{"Accept" => "application/json", "Content-Type" => "application/json"})
      # Accept: application/json; charset=UTF-8
      # Content-Type: application/json

#       {
# }
    end
  end

end
