CREATE PROCEDURE PRC_LLM_HTTP
    @Prompt NVARCHAR(MAX),            -- Parametr wejściowy: Prompt (zapytanie) do LLM
    @ResponseText NVARCHAR(MAX) OUTPUT -- Parametr wyjściowy: Odpowiedź otrzymana z LLM
AS
BEGIN
    DECLARE
        @Object INT,                    -- Uchwyt obiektu COM dla MSXML2.ServerXMLHTTP
        @hr INT,                       -- Zmienna przechowująca kod HRESULT z wywołań COM
        @URL NVARCHAR(200) = 'http://172.244.1.5:11434/api/chat', -- Adres URL API LLM
        @msg NVARCHAR(255),             -- Zmienna przechowująca komunikaty błędów
        @JSON NVARCHAR(MAX),            -- Zmienna przechowująca JSON z zapytaniem do LLM
        @statusVariant SQL_VARIANT,       -- Zmienna przechowująca status odpowiedzi HTTP (SQL_VARIANT dla elastyczności)
        @status INT,                      -- Zmienna przechowująca status odpowiedzi HTTP (po konwersji na INT)
        @responseTextVariant SQL_VARIANT, -- Zmienna przechowująca odpowiedź tekstową z LLM (SQL_VARIANT)
        @responseType NVARCHAR(MAX),    -- Zmienna przechowująca typ danych odpowiedzi z LLM
        @cleanedResponse NVARCHAR(MAX)  -- Zmienna przechowująca przetworzoną odpowiedź tekstową z LLM
    SET @ResponseText = 'BRAK ODPOWIEDZI'  -- Domyślna wartość odpowiedzi w przypadku błędu

    SET @JSON = '{
        "model": "deepseek-r1:1.5b",
        "messages": [{"role": "user", "content": "' + REPLACE(@Prompt, '"', '\"') + '"}],
        "temperature": 0.7,
        "stream": false
    }'                                     -- Konstruowanie JSON z zapytaniem

    -- Użyj stabilniejszego COM-a
    EXEC @hr = sp_OACreate 'MSXML2.ServerXMLHTTP.6.0', @Object OUT  -- Utworzenie obiektu COM
    IF @hr <> 0 BEGIN RAISERROR('sp_OACreate failed', 16, 1) RETURN END  -- Obsługa błędu utworzenia obiektu

    EXEC @hr = sp_OAMethod @Object, 'open', NULL, 'POST', @URL, false  -- Otwarcie połączenia HTTP POST
    IF @hr <> 0 BEGIN SET @msg = 'Open failed' GOTO EH END           -- Obsługa błędu otwarcia połączenia

    EXEC @hr = sp_OAMethod @Object, 'setRequestHeader', NULL, 'Content-Type', 'application/json' -- Ustawienie nagłówka Content-Type
    IF @hr <> 0 BEGIN SET @msg = 'SetRequestHeader failed' GOTO EH END           -- Obsługa błędu ustawienia nagłówka

    EXEC @hr = sp_OAMethod @Object, 'send', NULL, @JSON           -- Wysyłanie zapytania JSON do LLM
    IF @hr <> 0 BEGIN SET @msg = 'Send failed' GOTO EH END           -- Obsługa błędu wysłania zapytania

    EXEC @hr = sp_OAGetProperty @Object, 'status', @statusVariant OUT  -- Pobranie statusu odpowiedzi HTTP do zmiennej SQL_VARIANT
    IF @hr <> 0 BEGIN SET @msg = 'get Status failed' GOTO EH END           -- Obsługa błędu pobrania statusu
    SET @status = CONVERT(INT, @statusVariant);       -- Konwersja statusu HTTP na typ INT

    EXEC @hr = sp_OAGetProperty @Object, 'responseText', @responseTextVariant OUT  -- Pobranie odpowiedzi z LLM do zmiennej SQL_VARIANT
    IF @hr = 0
        BEGIN
            -- Sprawdź typ danych i odpowiednio przekonwertuj
            SET @responseType = CONVERT(NVARCHAR(MAX),SQL_VARIANT_PROPERTY(@responseTextVariant, 'BaseType')) -- Pobranie typu danych odpowiedzi

            IF @responseType = 'NVarChar' OR @responseType = 'VarChar'  -- Sprawdzenie, czy odpowiedź jest typu string
                BEGIN
                    DECLARE @responseTextString NVARCHAR(MAX)
                    SET @responseTextString = CAST(@responseTextVariant AS NVARCHAR(MAX)) -- Konwersja odpowiedzi na NVARCHAR(MAX)

                    BEGIN TRY
                        -- Pobierz odpowiedź JSON
                        SELECT @cleanedResponse = JSON_VALUE(@responseTextString, '$.message.content')

                        -- Usuń znaczniki <think> i </think> oraz białe znaki
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

                        -- Usuń wiodące i końcowe białe znaki
                        SET @ResponseText = LTRIM(RTRIM(@cleanedResponse))
                        SET @ResponseText = CASE
                                                WHEN LEN(@ResponseText) > 4000 THEN LEFT(@ResponseText, 4000) + N' [obcięte]'
                                                ELSE @ResponseText
                            END
                    END TRY
                    BEGIN CATCH
                        SET @ResponseText = 'Błąd parsowania JSON'  -- Obsługa błędu parsowania JSON
                    END CATCH
                END
            ELSE
                BEGIN
                    SET @ResponseText = 'Odpowiedź nie jest typu string. Typ: ' + @responseType  -- Obsługa przypadku, gdy odpowiedź nie jest stringiem
                END
        END
    ELSE
        BEGIN
            SET @ResponseText = 'Odpowiedź HTTP: ' + CAST(@status AS NVARCHAR) + ' (brak ResponseText)' -- Obsługa błędu pobrania odpowiedzi
        END

    EXEC sp_OADestroy @Object  -- Zwolnienie obiektu COM
    RETURN

    EH:  -- Etykieta dla bloku obsługi błędów
    IF @Object IS NOT NULL EXEC sp_OADestroy @Object  -- Zwolnienie obiektu COM w przypadku błędu
    RAISERROR(@msg, 16, 1)           -- Zgłoszenie błędu
    RETURN
END
go

