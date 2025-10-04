/*
Função que retorna o valor descritivo de um campo com opções fixas a partir do nome do campo e do valor do campo.
*/
CREATE FUNCTION dbo.GetCboxValue(
    @FIELD_NAME VARCHAR(100),
    @FIELD_VALUE VARCHAR(100)
)
RETURNS VARCHAR(max)
AS
BEGIN
    DECLARE @Result VARCHAR(100);
    
    SELECT @Result = tupla.valor 
    FROM PROTHEUS_DB.dbo.SX3010 AS X3
    CROSS APPLY (
        SELECT Item FROM MY_DB.dbo.split_string(TRIM(X3_CBOX), ';')
    ) AS itens(chaveValor)
    CROSS APPLY (
        SELECT
            (SELECT Item FROM MY_DB.dbo.split_string2(itens.chaveValor, '=') ORDER BY pos OFFSET 0 ROWS FETCH NEXT 1 ROWS ONLY) AS chave,
        	(SELECT Item FROM MY_DB.dbo.split_string2(itens.chaveValor, '=') ORDER BY pos OFFSET 1 ROWS FETCH NEXT 1 ROWS ONLY) AS valor
    ) AS tupla
    WHERE X3.D_E_L_E_T_ = ''
    AND X3.X3_CAMPO = @FIELD_NAME
    AND tupla.chave = @FIELD_VALUE;
    
    RETURN @Result;
END;