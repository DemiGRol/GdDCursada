/*-FUNCION-	CREATE FUNCTION [nombre]	RETURNS [tipoDato]	AS	BEGIN		[...]	END	GO-PROCEDURE-	CREATE PROCEDURE [nombre]	AS	BEGIN		[...]	END	GO-CURSOR-	DECLARE [nombre] CURSOR FOR [select statement]	OPEN [nombre]		FECTH NEXT FROM [nombre] INTO [variable]		WHILE @@FETCH_STATUS = 0		BEGIN			[...]		END	CLOSE [nombre]	DEALLOCATE [nombre]-TRIGGER-	CREATE TRIGGER [nombre] (AFTER|INSTEAD OF)	AS	BEGIN		[...]	END*/

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
	DECLARE @ocupacion int, @limite int

	SELECT @ocupacion = stoc_cantidad FROM STOCK WHERE stoc_producto = @articulo and stoc_deposito = @deposito
	SELECT @limite = stoc_stock_maximo FROM STOCK WHERE stoc_producto = @articulo and stoc_deposito = @deposito
	if @ocupacion >= @limite
		RETURN 'OCUPACION DEL DEPOSITO '+STR(@ocupacion*100/@limite)+'%'
	RETURN 'DEPOSITO COMPLETO' 
END;
GO

SELECT stoc_producto, stoc_deposito, stoc_cantidad, stoc_stock_maximo, dbo.ejer1(stoc_producto, stoc_deposito)
FROM STOCK
GO

--EJERCICIO 2
/*
Realizar una función que dado un artículo y una fecha, retorne el stock que
existía a esa fecha
*/

CREATE FUNCTION ejer2(@articulo char(8), @fecha smalldatetime)
RETURNS int
AS
BEGIN
	RETURN isnull((select sum(stoc_cantidad) from STOCK where stoc_producto = @articulo),0) +
		   isnull((select sum(item_cantidad) from Item_Factura 
						join Factura on fact_tipo+fact_sucursal+fact_numero = item_tipo+item_sucursal+item_numero
				   where item_producto = @articulo and fact_fecha > @fecha),0)
END
GO

--EJERCICIO 3
/*
Cree el/los objetos de base de datos necesarios para corregir la tabla empleado
en caso que sea necesario. Se sabe que debería existir un único gerente general
(debería ser el único empleado sin jefe). Si detecta que hay más de un empleado
sin jefe deberá elegir entre ellos el gerente general, el cual será seleccionado por
mayor salario. Si hay más de uno se seleccionara el de mayor antigüedad en la
empresa. Al finalizar la ejecución del objeto la tabla deberá cumplir con la regla
de un único empleado sin jefe (el gerente general) y deberá retornar la cantidad
de empleados que había sin jefe antes de la ejecución.
*/

CREATE PROCEDURE dbo.ejer3
AS
BEGIN
	DECLARE @cantidad int, @gg numeric(6,0)
	--me fijo cuantos empleados no tienen jefe
	SET @cantidad = (select count(empl_codigo) from Empleado where empl_jefe is null)
	IF @cantidad > 1
	BEGIN
		--me quedo con el gerente general
		select top 1 @gg = empl_codigo from Empleado order by empl_salario desc, empl_ingreso asc
		--actualizo la tabla empleado seteando como jefe al gerente
		update Empleado set empl_jefe = @gg where empl_jefe is null and empl_codigo <> @gg
	END
END
GO

--EJERCICIO 4
/*
Cree el/los objetos de base de datos necesarios para actualizar la columna de
empleado empl_comision con la sumatoria del total de lo vendido por ese
empleado a lo largo del último año. Se deberá retornar el código del vendedor
que más vendió (en monto) a lo largo del último año.*/CREATE PROCEDURE ejer4(@empleadoMasVentas numeric(6,0) OUT)ASBEGIN	DECLARE @empleado numeric(6,0)	DECLARE cur CURSOR FOR (select empl_codigo from Empleado)	OPEN cur	FETCH NEXT FROM cur INTO @empleado	WHILE @@FETCH_STATUS = 0	BEGIN		update Empleado 		set empl_comision = (select sum(fact_total) 							 from Factura 							 where fact_vendedor = @empleado and year(fact_fecha) = 2012)		where empl_codigo = @empleado		FETCH NEXT FROM cur INTO @empleado	END	CLOSE cur	DEALLOCATE cur		set @empleadoMasVentas = (select top 1 empl_codigo from Empleado order by empl_comision desc)ENDGO--EJERCICIO 5/*Realizar un procedimiento que complete con los datos existentes en el modelo
provisto la tabla de hechos denominada Fact_table tiene las siguiente definición:*/Create table Fact_table
(anio char(4) not null,
mes char(2) not null,
familia char(3) not null,
rubro char(4) not null,
zona char(3) not null,
cliente char(6) not null,
producto char(8) not null,
cantidad decimal(12,2),
monto decimal(12,2)
)
Alter table dbo.Fact_table Add primary key (anio, mes, familia, rubro, zona, cliente, producto)go--cantidad de un producto vendido para un año y mesCREATE FUNCTION cantProductoPorAnioYMes(@anio int, @mes int)RETURNS intASBEGIN	declare @cantidad int	set @cantidad = (select sum(item_cantidad)					 from Factura f						join Item_Factura on fact_tipo+fact_sucursal+fact_numero = item_tipo+item_sucursal+item_numero					 where YEAR(fact_Fecha) = @anio and MONTH(fact_fecha) = @mes)	RETURN @cantidadENDGOALTER PROCEDURE dbo.ejer5ASBEGIN	INSERT INTO dbo.Fact_table(anio, mes, familia, rubro, zona, cliente, producto, cantidad, monto)	SELECT distinct YEAR(fact_fecha), MONTH(fact_fecha), prod_familia, prod_rubro, isnull(depo_zona,-1), 					fact_cliente, item_producto, sum(item_cantidad), sum(item_cantidad*item_precio)	FROM Item_Factura 		join Factura on fact_tipo+fact_sucursal+fact_numero = item_tipo+item_sucursal+item_numero		join Producto on item_producto = prod_codigo		join STOCK on prod_codigo = stoc_producto		join DEPOSITO on depo_codigo = stoc_deposito	GROUP BY YEAR(fact_fecha), MONTH(fact_fecha), prod_familia, prod_rubro, depo_zona, fact_cliente, item_productoENDGOEXEC dbo.ejer5GO--EJERCICIO 6/*Realizar un procedimiento que si en alguna factura se facturaron componentes
que conforman un combo determinado (o sea que juntos componen otro
producto de mayor nivel), en cuyo caso deberá reemplazar las filas
correspondientes a dichos productos por una sola fila con el producto que
componen con la cantidad de dicho producto que corresponda*/CREATE PROCEDURE dbo.ejer6ASBEGIN	DECLARE @fact_numero char(8), @fact_tipo char(1), @fact_sucursal char(4), @producto_combo char(8), 			@cantidad_producto_combo decimal(12,2)	DECLARE curFactura CURSOR FOR (select fact_numero, fact_tipo, fact_sucursal from Factura)	OPEN curFactura		FETCH NEXT FROM curFactura INTO @fact_numero, @fact_tipo, @fact_sucursal		WHILE @@FETCH_STATUS = 0		BEGIN		DECLARE curProducto CURSOR FOR (select comp_producto										from Item_Factura join Composicion c on c.comp_componente = item_producto										where item_numero = @fact_numero and item_tipo = @fact_tipo and item_sucursal = @fact_sucursal											and item_cantidad >= comp_cantidad and comp_producto = @producto_combo										group by c.comp_producto										having count(*) = (select count(*) from Composicion c2 where c2.comp_producto = c.comp_producto))		OPEN curProducto		FETCH NEXT FROM curProducto into @producto_combo		WHILE @@FETCH_STATUS = 0		BEGIN			--calcula la cantidad máxima de combos que pueden formarse en esa compra			select @cantidad_producto_combo = MIN(FLOOR(item_cantidad/comp_componente))			from Item_Factura join Composicion on item_producto = comp_componente			where item_numero = @fact_numero and item_tipo = @fact_tipo and item_sucursal = @fact_sucursal					and item_cantidad >= comp_cantidad and comp_producto = @producto_combo			--inserta la nueva fila			insert into Item_Factura (item_tipo, item_sucursal, item_numero, item_producto, item_cantidad, item_precio)			select @fact_tipo, @fact_sucursal, @fact_numero, @producto_combo, @cantidad_producto_combo, 					(@cantidad_producto_combo * (select PROD_precio from Producto where prod_codigo = @producto_combo))			--resto la cantidad de combos maximos según aquellos que no se pudieron formar			update Item_Factura			set item_cantidad = i.item_cantidad - ( @cantidad_producto_combo * (select comp_cantidad from Composicion																				where i.item_producto = comp_componente																					and @producto_combo = comp_producto)),			item_precio = i.item_cantidad - ( @cantidad_producto_combo * (select comp_cantidad from Composicion																				where i.item_producto = comp_componente																					and @producto_combo = comp_producto))							* (select PROD_precio from Producto where prod_codigo = @producto_combo) 			from Item_Factura i, Composicion c			where i.item_numero = @fact_numero and i.item_tipo = @fact_tipo and i.item_sucursal = @fact_sucursal					and c.comp_producto = i.item_producto and comp_producto = @producto_combo			--elimina las filas extras			delete from Item_Factura			where item_numero = @fact_numero and item_tipo = @fact_tipo and item_sucursal = @fact_sucursal					and item_cantidad = 0			FETCH NEXT FROM curProducto INTO @producto_combo		END		CLOSE curProducto 		DEALLOCATE curProducto		FETCH NEXT FROM curFactura INTO @fact_numero, @fact_tipo, @fact_sucursal		END	CLOSE curFactura	DEALLOCATE curProductoENDGO--EJERCICIO 7/*Hacer un procedimiento que dadas dos fechas complete la tabla Ventas. Debe
insertar una línea por cada artículo con los movimientos de stock generados por
las ventas entre esas fechas. La tabla se encuentra creada y vacía.*/create table Ventas
(producto char(8) not null,
detalle char(50),
cantMovimientos int,
precioVentaPromedio decimal(12,2),
renglon int identity(1,1),
ganancia decimal(12,2)
)
Alter table dbo.Ventas Add primary key (producto)goCREATE PROCEDURE dbo.ejer7(@fecha1 smalldatetime, @fecha2 smalldatetime)ASBEGIN	INSERT INTO dbo.Ventas(producto, detalle, cantMovimientos, precioVentaPromedio, ganancia)	SELECT distinct item_producto, prod_detalle, count(item_producto), avg(item_precio), prod_precio*sum(item_cantidad)	FROM Item_Factura		JOIN Producto on prod_codigo = item_producto		JOIN Factura on fact_tipo+fact_sucursal+fact_numero = item_tipo+item_sucursal+item_numero	WHERE @fecha1 <= fact_fecha and fact_fecha <= @fecha2	GROUP BY item_producto, prod_detalle, prod_precioENDGOEXEC dbo.ejer7 '2010-01-23 00:00:00', '2011-08-16 00:00:00'GO--EJERCICIO 8/*Realizar un procedimiento que complete la tabla Diferencias de precios, para los
productos facturados que tengan composición y en los cuales el precio de
facturación sea diferente al precio del cálculo de los precios unitarios por
cantidad de sus componentes, se aclara que un producto que compone a otro,
también puede estar compuesto por otros y así sucesivamente, la tabla se debe
crear y está formada por las siguientes columnas:*/create table Diferencias
(producto char(8) not null,
detalle char(50),
cantComponentes int,
precioSumComponentes decimal(12,2),
precioCombo decimal(12,2)
)
Alter table dbo.Diferencias Add primary key (producto)goCREATE PROCEDURE dbo.ejer8ASBEGIN	INSERT INTO Diferencias (producto, detalle, cantComponentes, precioSumComponentes, precioCombo)	SELECT prod_codigo, prod_detalle, count(comp_producto), 			(select sum(p2.prod_precio) from Producto p2 join Composicion on p2.prod_codigo = comp_componente and p1.prod_codigo = comp_producto),			prod_precio	FROM Producto p1		JOIN Composicion on p1.prod_codigo = comp_producto	GROUP BY prod_codigo, prod_detalle, prod_precioENDGOEXEC dbo.ejer8GO--EJERCICIO 9/*Crear el/los objetos de base de datos que ante alguna modificación de un ítem de
factura de un artículo con composición realice el movimiento de sus
correspondientes componentes.Cuando vendo un producto combo, debo hacer el movimiento de stock para sus componentes.*/ALTER TRIGGER ejer9 ON item_factura AFTER INSERT ASBEGIN	DECLARE @producto char(8), @cantidad decimal(12,2), @deposito char(2)	--en un bloque de ventas, no todos los productos serán compuestos. Por eso creo un cursor.	DECLARE cur CURSOR FOR (select comp_componente, comp_cantidad*item_cantidad 							from inserted join Composicion on comp_producto = inserted.item_producto)	OPEN cur		FETCH NEXT FROM cur INTO @producto, @cantidad		WHILE @@FETCH_STATUS = 0		BEGIN			SELECT @deposito = stoc_deposito from STOCK where stoc_producto = @producto and stoc_cantidad > @cantidad			UPDATE STOCK			set stoc_cantidad = stoc_cantidad - @cantidad			where stoc_producto = @producto and stoc_deposito = @deposito						FETCH NEXT FROM cur INTO @producto, @cantidad		END	CLOSE cur	DEALLOCATE curENDGO--EJERCICIO 10/*Crear el/los objetos de base de datos que ante el intento de borrar un artículo
verifique que no exista stock y si es así lo borre en caso contrario que emita un
mensaje de error.*/CREATE TRIGGER ejer10 ON Producto INSTEAD OF DELETEASBEGIN	DECLARE @producto char(8)	DECLARE cur CURSOR FOR (select prod_codigo from deleted)	OPEN cur		FETCH NEXT FROM cur INTO @producto		WHILE @@FETCH_STATUS = 0		BEGIN			IF((SELECT count(*) FROM STOCK WHERE stoc_producto = @producto and stoc_cantidad > 0) > 0)				PRINT ('No se puede eliminar el producto '+ @producto)			ELSE			BEGIN				DELETE FROM STOCK where stoc_producto = @producto				DELETE FROM Producto WHERE prod_codigo = @producto			END			FETCH NEXT FROM cur INTO @producto		ENDENDGO--EJERCICIO 11/*Cree el/los objetos de base de datos necesarios para que dado un código de
empleado se retorne la cantidad de empleados que este tiene a su cargo (directa o
indirectamente). Solo contar aquellos empleados (directos o indirectos) que
tengan un código mayor que su jefe directo.*/CREATE FUNCTION ejer11(@empleado numeric(6,0))RETURNS intASBEGIN	DECLARE @cantidad int	select @cantidad = 0	if((select count(*) from Empleado where empl_jefe = @empleado and empl_codigo > empl_jefe) = 0)		return @cantidad	select @cantidad = count(*) from Empleado where empl_jefe = @empleado and empl_codigo > empl_jefe	DECLARE cur CURSOR FOR (select empl_codigo from Empleado where empl_jefe = @empleado and empl_codigo > empl_jefe)	OPEN cur		DECLARE @jefe numeric(6,0)		FETCH NEXT FROM cur INTO @jefe		WHILE @@FETCH_STATUS = 0		BEGIN			select @cantidad = @cantidad + dbo.ejer11(@jefe)			FETCH NEXT FROM cur INTO @jefe		END	CLOSE cur	DEALLOCATE cur	RETURN @cantidadENDGO--EJERCICIO 12/*Cree el/los objetos de base de datos necesarios para que nunca un producto
pueda ser compuesto por sí mismo. Se sabe que en la actualidad dicha regla se
cumple y que la base de datos es accedida por n aplicaciones de diferentes tipos
y tecnologías. No se conoce la cantidad de niveles de composición existentes.*/CREATE TRIGGER ejer12 ON Composicion AFTER INSERT, UPDATEASBEGIN	DECLARE @producto char(8), @cantidadSelfComposed int, @componente char(8)	set @cantidadSelfComposed = 0	DECLARE cur CURSOR FOR (SELECT comp_producto, comp_componente from inserted)	OPEN cur		FETCH NEXT FROM cur INTO @producto, @componente		WHILE @@FETCH_STATUS = 0		BEGIN			IF(@producto = @componente)				set @cantidadSelfComposed = @cantidadSelfComposed + 1			FETCH NEXT FROM cur INTO @producto, @componente		END	CLOSE cur	DEALLOCATE cur	IF(@cantidadSelfComposed > 0)	BEGIN		ROLLBACK TRANSACTION		PRINT('No puede existir un producto compuesto por si mismo')	END	IF EXISTS (select 1 from Composicion where comp_producto = comp_componente)	BEGIN		ROLLBACK TRANSACTION		PRINT('No puede existir un producto compuesto por si mismo')	ENDENDGO--OTRA FORMACREATE TRIGGER ejer12V2 ON Composicion AFTER INSERT, UPDATEASBEGIN	IF (EXISTS (select 1 from inserted where comp_producto = comp_componente)) 	BEGIN		ROLLBACK TRANSACTION		PRINT('No puede existir un producto compuesto por si mismo')	END	IF EXISTS (select 1 from Composicion where comp_producto = comp_componente)	BEGIN		ROLLBACK TRANSACTION		PRINT('No puede existir un producto compuesto por si mismo')	ENDENDGO--EJERCICIO 13/*Cree el/los objetos de base de datos necesarios para implantar la siguiente regla
“Ningún jefe puede tener un salario mayor al 20% de las suma de los salarios de
sus empleados totales (directos + indirectos)”. Se sabe que en la actualidad dicha
regla se cumple y que la base de datos es accedida por n aplicaciones de
diferentes tipos y tecnologías*/CREATE FUNCTION fAux13(@jefe numeric(6,0))RETURNS decimal(12,2)ASBEGIN	DECLARE @salarioCompuesto decimal(12,2), @empleado numeric(6,0)	SET @salarioCompuesto = 0	DECLARE cur CURSOR FOR (select empl_codigo, empl_Salario from Empleado where empl_jefe = @jefe)	OPEN cur	BEGIN		FETCH NEXT FROM cur INTO @empleado, @salarioCompuesto		WHILE @@FETCH_STATUS = 0		BEGIN			select @salarioCompuesto = @salarioCompuesto + dbo.fAux13(@empleado)			FETCH NEXT FROM cur INTO @empleado, @salarioCompuesto		END	END	CLOSE cur	DEALLOCATE cur	RETURN @salarioCompuestoENDGOCREATE TRIGGER ejer13 ON Empleado AFTER INSERT, UPDATE, DELETEASBEGIN	IF(EXISTS (select 1 from inserted i where i.empl_salario < 0.2 * dbo.fAux13(i.empl_codigo)))	BEGIN		ROLLBACK TRANSACTION 		PRINT('EL SUELDO DEL JEFE NO CUMPLE CON LA REGLA')	END	IF(EXISTS (select 1 from deleted d where d.empl_salario < 0.2 * dbo.fAux13(d.empl_codigo)))	BEGIN		ROLLBACK TRANSACTION 		PRINT('EL SUELDO DEL JEFE NO CUMPLE CON LA REGLA')	END	IF(EXISTS (select empl_codigo from Empleado where empl_salario < 0.2 * dbo.fAux13(empl_codigo)))	BEGIN		ROLLBACK TRANSACTION 		PRINT('EL SUELDO DEL JEFE NO CUMPLE CON LA REGLA')	ENDENDGO--EJERCICIO 14/*Agregar el/los objetos necesarios para que si un cliente compra un producto
compuesto a un precio menor que la suma de los precios de sus componentes
que imprima la fecha, que cliente, que productos y a qué precio se realizó la
compra. No se deberá permitir que dicho precio sea menor a la mitad de la suma
de los componentes.*/CREATE FUNCTION sumaPrecioComponentes(@producto char(8)) --ya se que el producto que le paso está en composicionRETURNS decimal(12,2)									--valida que no sea un producto compuesto por si mismoASBEGIN	DECLARE @sumaPrecio decimal(12,2), @componente decimal(12,2), @cantidad int, @precio decimal(12,2)	SET @sumaPrecio = 0	SET @precio = 0	DECLARE cur CURSOR FOR (select prod_codigo, prod_precio, comp_cantidad from Composicion join Producto on prod_codigo = comp_componente where @producto = comp_producto)	OPEN cur		FETCH NEXT FROM cur INTO @componente, @precio, @cantidad		WHILE @@FETCH_STATUS = 0		BEGIN			select @sumaPrecio += @precio * @cantidad + dbo.sumaPrecioComponentes(@componente)			FETCH NEXT FROM cur INTO @componente, @precio, @cantidad		END	CLOSE cur	DEALLOCATE cur	RETURN @sumaPrecioENDGOCREATE TRIGGER ejer14 ON Factura AFTER INSERTASBEGIN	DECLARE @fecha smalldatetime, @cliente char(6), @producto char(8), @precio decimal(12,2)	DECLARE cur CURSOR FOR (select distinct fact_fecha, fact_cliente, item_producto, item_precio 							from inserted join Item_Factura on fact_tipo+fact_sucursal+fact_numero = item_tipo+item_sucursal+item_numero							where item_precio < dbo.sumaPrecioComponentes(item_producto) and item_producto in (select comp_producto from Composicion))	OPEN cur	BEGIN		FETCH NEXT FROM cur INTO @fecha, @cliente, @producto, @precio		WHILE @@FETCH_STATUS = 0		BEGIN 			IF(@precio < 0.5 * dbo.sumaPrecioComponentes(@producto))			BEGIN				ROLLBACK TRANSACTION				PRINT('EL PRECIO DE COMPRA NO CUMPLE CON LA REGLA')			END			PRINT @fecha+@cliente+@producto+@precio		END	END	CLOSE cur	DEALLOCATE curENDGO--EJERCICIO 15/*Cree el/los objetos de base de datos necesarios para que el objeto principal
reciba un producto como parametro y retorne el precio del mismo.
Se debe prever que el precio de los productos compuestos sera la sumatoria de
los componentes del mismo multiplicado por sus respectivas cantidades. No se
conocen los nivles de anidamiento posibles de los productos. Se asegura que
nunca un producto esta compuesto por si mismo a ningun nivel. El objeto
principal debe poder ser utilizado como filtro en el where de una sentencia
select.*/CREATE FUNCTION selfComposedInAnyLevel(@producto char(8))RETURNS bitASBEGIN	DECLARE @isSelfComposed int, @componente char(8)	set @isSelfComposed = 0	DECLARE cur CURSOR FOR (SELECT comp_componente from Composicion where comp_producto = @producto)	OPEN cur		FETCH NEXT FROM cur INTO @producto, @componente		WHILE @@FETCH_STATUS = 0		BEGIN			IF(@producto = @componente)				set @isSelfComposed = 1				PRINT('SE COMPONE DE SI MISMO')			FETCH NEXT FROM cur INTO @producto, @componente		END	CLOSE cur	DEALLOCATE cur	RETURN @isSelfComposedENDGOCREATE FUNCTION ejer15(@producto char(8))RETURNS decimal(12,2)ASBEGIN	DECLARE @precio decimal(12,2)	IF(@producto in (select comp_producto from Composicion) and dbo.selfComposedInAnyLevel(@producto) = 0)	BEGIN		select @precio = dbo.sumaPrecioComponentes(@producto)	END	select @precio = prod_precio from Producto where prod_codigo = @producto	RETURN @precioENDGO