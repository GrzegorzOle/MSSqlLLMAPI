# Using SQL Server with Ollama via HTTP and SQL Scripts

This guide demonstrates how to integrate SQL Server (MSSQL) with the Ollama LLM API using T-SQL and HTTP requests. It includes configuration steps and usage patterns to make API calls directly from within SQL Server using OLE Automation.

---

## Prerequisites

To use HTTP within MSSQL, you need to enable OLE Automation Procedures. Run the following commands in SQL Server Management Studio:

```sql
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
EXEC sp_configure 'Ole Automation Procedures', 1;
RECONFIGURE;
```

> ⚠️ Warning: Enabling `Ole Automation Procedures` can pose a security risk. Ensure that your SQL Server instance is properly secured and isolated.

---

## SQL Scripts Overview

### 1. `FUNC_LLM_HTTP.sql`

This SQL file contains a user-defined function that performs an HTTP request to the Ollama API. It is responsible for sending the prompt and returning the response as text.

### 2. `PRC_LLM_HTTP.sql`

This SQL file contains a stored procedure that uses the `FUNC_LLM_HTTP` function to send a prompt to Ollama and process the returned message.

---

## Sample Prompt

To interact with the model, use the following SQL code:

```sql
DECLARE @result NVARCHAR(MAX);

EXEC Prc_LLM_HTTP
     @Prompt = N'Hello?',
     @ResponseText = @result OUTPUT;

SELECT @result AS ResponseLLM;
```

or function
```sql
SELECT dbo.Func_LLM_HTTP(N'Hello?') AS ResponseLLM;
```

### Expected Response:

```
Hello! How can I assist you today? 😊
```

---

## Configuration Reminder

Update the IP address inside the SQL scripts if your Ollama API server is hosted on a different machine.

### Example:

```sql
-- Replace this IP with your Ollama server IP
http://192.168.0.123:11434/api/generate
```

Make sure to change `192.168.0.123` to your server’s actual IP.

---

## Final Notes

- Ensure that SQL Server has access to the network where the Ollama API is hosted.
- These scripts are for controlled/internal usage only due to security and execution context limitations.
- Do not expose SQL Server with OLE enabled to the internet.

---

Happy prompting! 🧠📡
