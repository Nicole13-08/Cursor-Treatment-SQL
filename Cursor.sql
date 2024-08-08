USE []
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER  PROCEDURE [PROD_STG_CORE].[PROC_CURSOR]
@VCurrency NVARCHAR(20) ,
@Vdate NVARCHAR(10)
AS


BEGIN

DECLARE @FIRST_DAY     NVARCHAR(70)
DECLARE @EOM_DATE      NVARCHAR(70)

SET @Vdate =  CAST(CAST(CONVERT(DATE, @Vdate ,105) AS DATE) AS nvarchar(10)) 
SET @EOM_DATE = CAST(CAST( EOMONTH(@Vdate) AS DATE) AS nvarchar(10)) 
SET @FIRST_DAY = CAST(CAST( DATEADD(DAY,1,EOMONTH(@Vdate,-1))AS DATE) AS nvarchar(10)) 

--PRINT @Vdate
--PRINT @FIRST_DAY
--PRINT @EOM_DATE


---cCreate a temporary table
IF EXISTS(SELECT 1 FROM TempDB.sys.tables WHERE name LIKE '%Temp1' )
BEGIN

DROP TABLE #Temp1
END

CREATE  TABLE #Temp1
  ( 
  Customer_Id NVARCHAR(20) ,
  Amount DECIMAL(18,2),
  Currency_Cd NVARCHAR(20),
  Event_Date DATE,
  row_nb NVARCHAR(20) 
  )

EXECUTE(' INSERT INTO #Temp1
SELECT
T.Customer_Id, SUM(T.Amount), T.Currency_Cd, T.Event_Date,
  ROW_NUMBER() OVER(PARTITION BY Customer_Id ORDER BY Customer_Id ) as row_nb

from Customer_Transaction_TBL as T
WHERE Customer_Id=''977977'' AND
Event_Date between CAST('''+@FIRST_DAY+''' AS DATE) and CAST('''+@EOM_DATE+''' AS DATE)
and Currency_Cd= '+@VCurrency+'

GROUP BY T.Customer_Id, T.Currency_Cd, T.Event_Date
order by T.Event_Date  

')



--INSERT THE MISSING DAYS -- BEGIN---
BEGIN
DECLARE @VT_DATE DATE 

DECLARE CUR_HOL CURSOR LOCAL FOR

SELECT DISTINCT CONVERT(DATE, T_DATE ,105) 
FROM Calender_TBL
WHERE 
CONVERT(DATE, T_DATE ,105) BETWEEN @FIRST_DAY and @EOM_DATE
AND 
CONVERT(DATE, T_DATE ,105) NOT IN 
 (SELECT DISTINCT Event_Date FROM Customer_Transaction_TBL
  WHERE Customer_Id='977977' AND
     Event_Date  BETWEEN @FIRST_DAY and @EOM_DATE and 
     Currency_Cd= @VCurrency) 


OPEN CUR_HOL
FETCH NEXT FROM CUR_HOL INTO @VT_DATE

 WHILE @@FETCH_STATUS = 0
 BEGIN
 PRINT @VT_DATE
EXECUTE('INSERT INTO #Temp1
select T.Customer_Id, SUM(T.Amount), T.Currency_Cd,  '''+@VT_DATE+'''  Event_Date, row_nb
from #Temp1 as T
WHERE  Event_Date = (SELECT MAX(Event_Date) from #Temp1 as T WHERE Event_Date <  '''+@VT_DATE+'''  ) 
GROUP BY T.Customer_Id,  T.Currency_Cd, T.Event_Date,row_nb
order by T.Event_Date
 ')

FETCH NEXT FROM CUR_HOL INTO @VT_DATE
  
END
CLOSE CUR_HOL
DEALLOCATE CUR_HOL
END
--INSERT THE MISSING DAYS -- END---

--select * from #Temp1 order by Event_Posted_Date 

 

END
