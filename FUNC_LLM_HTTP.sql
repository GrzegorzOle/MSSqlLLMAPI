CREATE FUNCTION FN_LLM_HTTP (
    @Prompt NVARCHAR(MAX)
)
    RETURNS NVARCHAR(MAX)
AS
BEGIN
    DECLARE
        @Object INT,
        @hr INT,
        @URL NVARCHAR(200) = 'http://172.244.1.5:11434/api/chat',
        @msg NVARCHAR(255),
        @JSON NVARCHAR(MAX),
        @statusVariant SQL_VARIANT,
        @status INT,
        @responseTextVariant SQL_VARIANT,
        @responseType NVARCHAR(MAX),
        @cleanedResponse NVARCHAR(MAX),
        @Result NVARCHAR(MAX)

    SET @Result = 'BRAK ODPOWIEDZI'

    SET @JSON = '{
        "model": "deepseek-r1:1.5b",
        "messages": [{"role": "user", "content": "' + REPLACE(@Prompt, '"', '\"') + '"}],
        "temperature": 0.7,
        "stream": false
    }'

    EXEC @hr = sp_OACreate 'MSXML2.ServerXMLHTTP.6.0', @Object OUT
    IF @hr <> 0
        BEGIN
            SET @Result = 'Błąd: sp_OACreate failed'
            GOTO Cleanup
        END

    EXEC @hr = sp_OAMethod @Object, 'open', NULL, 'POST', @URL, false
    IF @hr <> 0
        BEGIN
            SET @msg = 'Open failed'
            GOTO ErrorHandler
        END

    EXEC @hr = sp_OAMethod @Object, 'setRequestHeader', NULL, 'Content-Type', 'application/json'
    IF @hr <> 0
        BEGIN
            SET @msg = 'SetRequestHeader failed'
            GOTO ErrorHandler
        END

    EXEC @hr = sp_OAMethod @Object, 'setTimeouts', NULL, 30000, 30000, 30000, 30000
    IF @hr <> 0
        BEGIN
            SET @msg = 'setTimeouts failed'
            GOTO ErrorHandler
        END

    EXEC @hr = sp_OAMethod @Object, 'send', NULL, @JSON
    IF @hr <> 0
        BEGIN
            SET @msg = 'Send failed'
            GOTO ErrorHandler
        END

    EXEC @hr = sp_OAGetProperty @Object, 'status', @statusVariant OUT
    IF @hr <> 0
        BEGIN
            SET @msg = 'get Status failed'
            GOTO ErrorHandler
        END
    SET @status = CONVERT(INT, @statusVariant)

    EXEC @hr = sp_OAGetProperty @Object, 'responseText', @responseTextVariant OUT
    IF @hr = 0
        BEGIN
            SET @responseType = CONVERT(NVARCHAR(MAX), SQL_VARIANT_PROPERTY(@responseTextVariant, 'BaseType'))

            IF @responseType = 'NVarChar' OR @responseType = 'VarChar'
                BEGIN
                    DECLARE @responseTextString NVARCHAR(MAX)
                    SET @responseTextString = CAST(@responseTextVariant AS NVARCHAR(MAX))

                    SELECT @cleanedResponse = JSON_VALUE(@responseTextString, '$.message.content')

                    SET @cleanedResponse = REPLACE(
                            REPLACE(
                                    REPLACE(
                                            REPLACE(@cleanedResponse, '<think>', ''),
                                            '</think>', ''
                                    ),
                                    CHAR(10),
                                    ''
                            ),
                            CHAR(13),
                            ''
                                           )

                    SET @Result = LTRIM(RTRIM(@cleanedResponse))
                    SET @Result = CASE
                                      WHEN LEN(@Result) > 4000 THEN LEFT(@Result, 4000) + N' [obcięte]'
                                      ELSE @Result
                        END

                END
            ELSE
                BEGIN
                    SET @Result = 'Odpowiedź nie jest typu string. Typ: ' + @responseType
                END
        END
    ELSE
        BEGIN
            SET @Result = 'Odpowiedź HTTP: ' + CAST(@status AS NVARCHAR) + ' (brak ResponseText)'
        END

    Cleanup:
    IF @Object IS NOT NULL EXEC sp_OADestroy @Object
    RETURN @Result

    ErrorHandler:
    IF @Object IS NOT NULL EXEC sp_OADestroy @Object
    SET @Result = @msg
    RETURN @Result
END
go