USE GD1C2024
GO
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'RENAPER')
BEGIN 
	EXEC ('CREATE SCHEMA RENAPER')
END
GO

--CREATE
CREATE TABLE RENAPER.BI_Dimension_Sucursal(
	sucursal_id int not null, --PK
	sucursal_detalle varchar(255),
	sucursal_direccion varchar(255)	--,
	--sucursal_importe_pago_cuotas numeric(18,0)
);
GO

CREATE TABLE RENAPER.BI_Dimension_Rango_Etario(
	id_rango_etario int identity(1,1) not null, --PK
	menor_a_25 bit null,
	entre_25_y_35 bit null,
	entre_35_y_50 bit null,
	mayor_a_50 bit null
);
GO
--ALTER
ALTER TABLE RENAPER.BI_Dimension_Sucursal ADD PRIMARY KEY (sucursal_id) 
GO

ALTER TABLE RENAPER.BI_Dimension_Rango_Etario ADD PRIMARY KEY (id_rango_etario) 
GO

--FUNCTIONS
CREATE FUNCTION RENAPER.calcularEdad(@fechaNacimiento DATE)
RETURNS int
BEGIN
	DECLARE @edad INT;

	SELECT @edad = DATEDIFF(YEAR,@fechaNacimiento,GETDATE()) - 
					CASE WHEN ((MONTH(@fechaNacimiento) = MONTH(GETDATE()) and DAY(@fechaNacimiento) >= DAY(GETDATE())) or MONTH(@fechaNacimiento) > MONTH(GETDATE()))
						THEN 0
						ELSE 1
					END
	RETURN @edad
END
GO

--Estas se usan para la migración del rango etáreo
CREATE FUNCTION RENAPER.menorA25(@edad int)
RETURNS int
BEGIN
	IF @edad >= 0 and @edad < 25
		RETURN 1
	RETURN 0
END
GO

CREATE FUNCTION RENAPER.entre25Y35(@edad int)
RETURNS int
BEGIN
	IF @edad >= 25 and @edad < 35
		RETURN 1
	RETURN 0
END
GO

CREATE FUNCTION RENAPER.entre35Y50(@edad int)
RETURNS int
BEGIN
	IF @edad >= 35 and @edad <= 50
		RETURN 1
	RETURN 0
END
GO

CREATE FUNCTION RENAPER.mayorA50(@edad int)
RETURNS int
BEGIN
	IF @edad > 50
		RETURN 1
	RETURN 0
END
GO

--Esta se usa para vincular una edad con la tabla rango etáreo
CREATE FUNCTION RENAPER.calcularRangoEtario(@edad int)
RETURNS int
BEGIN
	RETURN (SELECT CASE	WHEN RENAPER.menorA25(@edad) = 1 then 4
						WHEN RENAPER.entre25Y35(@edad) = 1 then 3
						WHEN RENAPER.entre35Y50(@edad) = 1 then 2
						ELSE 1
					END)
END
GO

SELECT  e.empleado_legajo, e.empleado_fecha_nacimiento, RENAPER.calcularRangoEtareo(RENAPER.calcularEdad(empleado_fecha_nacimiento)) as rangoEtario
FROM RENAPER.Empleado e

/* EJEMPLO -> Uso la misma tabla independientemente de si se trata de un cliente o empleado
SELECT  RENAPER.calcularRangoEtario(RENAPER.calcularEdad(cliente_fecha_nacimiento))
FROM RENAPER.Cliente

SELECT RENAPER.calcularRangoEtario(RENAPER.calcularEdad(empleado_fecha_nacimiento))
FROM RENAPER.Empleado
*/

--PROCEDURES
CREATE PROCEDURE RENAPER.MigrarBI_Dimension_Sucursal
AS
BEGIN
	INSERT INTO RENAPER.BI_Dimension_Sucursal(sucursal_id, sucursal_detalle, sucursal_direccion--, sucursal_importe_pago_cuotas)
		SELECT s.sucursal_codigo, s.sucursal_nombre, s.sucursal_direccion--, sum()
		FROM RENAPER.Sucursal s
END
GO

CREATE PROCEDURE RENAPER.MigrarBI_Dimension_Rango_Etario
AS
BEGIN
	INSERT INTO RENAPER.BI_Dimension_Rango_Etario_Cliente(menor_a_25, entre_25_y_35, entre_35_y_50, mayor_a_50)
		SELECT RENAPER.menorA25(RENAPER.calcularEdad(c.cliente_fecha_nacimiento)), RENAPER.entre25Y35(RENAPER.calcularEdad(c.cliente_fecha_nacimiento)), 
			   RENAPER.entre35Y50(RENAPER.calcularEdad(c.cliente_fecha_nacimiento)), RENAPER.mayorA50(RENAPER.calcularEdad(c.cliente_fecha_nacimiento))
		FROM RENAPER.Cliente c
		UNION 
		SELECT RENAPER.menorA25(RENAPER.calcularEdad(e.empleado_fecha_nacimiento)), RENAPER.entre25Y35(RENAPER.calcularEdad(e.empleado_fecha_nacimiento)), 
			   RENAPER.entre35Y50(RENAPER.calcularEdad(e.empleado_fecha_nacimiento)), RENAPER.mayorA50(RENAPER.calcularEdad(e.empleado_fecha_nacimiento))
		FROM RENAPER.Empleado e
END
GO

--EXEC
BEGIN TRANSACTION

	EXEC RENAPER.MigrarBI_Dimension_Sucursal
	EXEC RENAPER.MigrarBI_Dimension_Rango_Etario

COMMIT TRANSACTION
GO