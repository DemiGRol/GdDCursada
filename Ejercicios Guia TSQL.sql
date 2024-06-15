--EJERCICIO 1
/*
Hacer una función que dado un artículo y un deposito devuelva un string que
indique el estado del depósito según el artículo. Si la cantidad almacenada es
menor al límite retornar “OCUPACION DEL DEPOSITO XX %” siendo XX el
% de ocupación. Si la cantidad almacenada es mayor o igual al límite retornar
“DEPOSITO COMPLETO”
*/
CREATE FUNCTION ejer1(@articulo char(8), @deposito char(2))
RETURNS varchar(50)
BEGIN
	DECLARE @ocupacion int
	DECLARE @ocupacionStr varchar(50)

	if (SELECT stoc_cantidad FROM STOCK WHERE stoc_producto = @articulo and stoc_deposito = @deposito) <
	   (SELECT stoc_stock_maximo FROM STOCK WHERE stoc_producto = @articulo and stoc_deposito = @deposito)
	BEGIN
		select @ocupacion = (select stoc_cantidad*100/stoc_stock_maximo from STOCK WHERE stoc_producto = @articulo and stoc_deposito = @deposito)
		set @ocupacionStr = 'OCUPACION DEL DEPOSITO '+CAST(@ocupacion AS varchar(3))+'%'
	END
	else set @ocupacionStr = 'DEPOSITO COMPLETO' 
	return @ocupacionStr
END;
GO

SELECT stoc_producto, stoc_deposito, stoc_cantidad, stoc_stock_maximo, dbo.ejer1(stoc_producto, stoc_deposito)
FROM STOCK

--EJERCICIO 2