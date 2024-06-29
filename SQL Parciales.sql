--Parciales SQL
/*
1. Retornar todos los clientes que por 2 anos consecutivos NO
COMPRARON ningún producto. De estos clientes devolver:
a. Código y razón social del cliente
b. Total comprando (en toda la historia)
c. Cantidad de rubros comprados (en toda la historia)

El resultado deberá ser ordenado por los clientes que compraron en el 2012,
siendo estos los primeros, luego el resto.
*/

SELECT clie_codigo, clie_razon_social, sum(fact_total) as TotalComprado, count(distinct prod_rubro) as RubrosComprados
FROM Cliente c1
	JOIN Factura f1 on c1.clie_codigo = f1.fact_cliente 
	JOIN Item_Factura i1 on f1.fact_numero+f1.fact_sucursal+f1.fact_tipo = i1.item_numero+i1.item_sucursal+i1.item_tipo
	JOIN Producto p1 on p1.prod_codigo = i1.item_producto 
WHERE clie_codigo in (select fact_cliente
					  from Cliente c2 
						join Factura f2 on f2.fact_cliente = c2.clie_codigo
					  where YEAR(f1.fact_fecha) = YEAR(f2.fact_fecha) + 1 
						or YEAR(f1.fact_fecha) = YEAR(f2.fact_fecha) - 1 )
GROUP BY c1.clie_codigo, c1.clie_razon_social

--FALTA PRIORIZAR LOS QUE COMPRARON EN 2012: cliente 01772 debe ir último.
--case when YEAR(f1.fact_fecha) = 2012 then 1 else 0 end desc

/*
Realizar una consulta SQL que permita saber si un cliente compro un
por encima del promedio de compras de todos los clientes del 2012.
De estos clientes mostrar para el 2012:

1. El cliente
2. La razón social del cliente
3. El producto que en cantidades más compro.
4. El nombre del producto del punto 3.
5. Cantidad de productos distintos comprados por el
cliente.
6. Cantidad de productos con composición comprados
por el cliente.

El resultado deberá ser ordenado poniendo primero aquellos clientes
que compraron más de entre 5 y 10 productos distintos en el 2012.
*/
SELECT clie_codigo, clie_razon_social,
	(select top 1 i2.item_producto
	 from Item_Factura i2 
		JOIN Factura f2 on i2.item_tipo + i2.item_sucursal + i2.item_numero = f2.fact_tipo + f2.fact_sucursal + f2.fact_numero
	 where f2.fact_cliente = c1.clie_codigo and YEAR(f2.fact_fecha) = 2012
	 group by i2.item_producto
	 order by sum(i2.item_cantidad) desc) as ProductoMasComprado,

	 (select top 1 i2.item_producto
	 from Item_Factura i2 
		JOIN Factura f2 on i2.item_tipo + i2.item_sucursal + i2.item_numero = f2.fact_tipo + f2.fact_sucursal + f2.fact_numero
		JOIN Producto p2 on p2.prod_codigo = i2.item_producto
	 where f2.fact_cliente = c1.clie_codigo and YEAR(f2.fact_fecha) = 2012
	 group by i2.item_producto
	 order by sum(i2.item_cantidad) desc) as DetalleProductoMasComprado,

	 COUNT(distinct i1.item_producto) as CantidadProductosDistintos,

	 (select count(distinct )
	  from Producto p3
		join Composicion comp1 on comp1.comp_producto = p3.prod_codigo
	  where i1.item_producto = p3.prod_codigo)

FROM Factura f1
	JOIN Cliente c1 on f1.fact_cliente = c1.clie_codigo
	JOIN Item_Factura i1 on i1.item_tipo + i1.item_sucursal + i1.item_numero = f1.fact_tipo + f1.fact_sucursal + f1.fact_numero
	JOIN Producto p1 on p1.prod_codigo = i1.item_producto
WHERE YEAR(f1.fact_fecha) = 2012
GROUP BY clie_codigo, clie_razon_social
