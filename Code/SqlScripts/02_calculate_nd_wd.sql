/*

Purpose:
1. Loads clean first generic launch data from Stg_FirstGenericLaunches.
2. Loads clean Medicaid SDUD data from staging tables.
3. Creates automatic brand/generic drug-name matching terms.
4. Checks matching quality.
5. Calculates state-level Numeric Distribution and Weighted Distribution.

Required staging tables:
- Stg_FirstGenericLaunches
- Stg_SDUD_2017
- Stg_SDUD_2018
- Stg_SDUD_2019
- Stg_SDUD_2020
- Stg_SDUD_2021
- Stg_SDUD_2022
- Stg_SDUD_2023
- Stg_SDUD_2024
- Stg_SDUD_2025

If one SDUD year table does not exist, the script skips it.
*/

USE GenericLaunchResearch;
GO


TRUNCATE TABLE FirstGenericLaunches;
GO

INSERT INTO FirstGenericLaunches
(
    GenericName,
    BrandName,
    ApprovalDate,
    TherapeuticClass
)
SELECT
    LTRIM(RTRIM(GenericIngredient)) AS GenericName,
    LTRIM(RTRIM(BrandName)) AS BrandName,
    TRY_CONVERT(DATE, ApprovalDate) AS ApprovalDate,
    LTRIM(RTRIM(TherapeuticClassManual)) AS TherapeuticClass
FROM Stg_FirstGenericLaunches
WHERE UPPER(LTRIM(RTRIM(UseInStudy))) = 'YES'
  AND TRY_CONVERT(DATE, ApprovalDate) IS NOT NULL;
GO

SELECT COUNT(*) AS FirstGenericLaunchCount
FROM FirstGenericLaunches;
GO



TRUNCATE TABLE MedicaidUtilization;
GO

DECLARE @y INT = 2017;
DECLARE @table SYSNAME;
DECLARE @sql NVARCHAR(MAX);

WHILE @y <= 2025
BEGIN
    SET @table = CONCAT('Stg_SDUD_', @y);

    IF OBJECT_ID(N'dbo.' + @table, N'U') IS NOT NULL
    BEGIN
        SET @sql = N'
        INSERT INTO MedicaidUtilization
        (
            Year,
            Quarter,
            StateCode,
            DrugName,
            NDC,
            Prescriptions,
            ReimbursedAmount
        )
        SELECT
            TRY_CONVERT(INT, [Year]) AS Year,
            TRY_CONVERT(INT, [Quarter]) AS Quarter,
            UPPER(LTRIM(RTRIM(CONVERT(NVARCHAR(20), [State])))) AS StateCode,
            UPPER(LTRIM(RTRIM(CONVERT(NVARCHAR(300), [Product Name])))) AS DrugName,
            LTRIM(RTRIM(CONVERT(NVARCHAR(50), [NDC]))) AS NDC,
            TRY_CONVERT(FLOAT, NULLIF(LTRIM(RTRIM(CONVERT(VARCHAR(50), [Number of Prescriptions]))), '''')) AS Prescriptions,
            TRY_CONVERT(FLOAT, NULLIF(LTRIM(RTRIM(CONVERT(VARCHAR(50), [Total Amount Reimbursed]))), '''')) AS ReimbursedAmount
        FROM dbo.' + QUOTENAME(@table) + N'
        WHERE LOWER(CONVERT(VARCHAR(20), [Suppression Used])) IN (''false'', ''0'')
          AND TRY_CONVERT(FLOAT, NULLIF(LTRIM(RTRIM(CONVERT(VARCHAR(50), [Number of Prescriptions]))), '''')) IS NOT NULL
          AND TRY_CONVERT(FLOAT, NULLIF(LTRIM(RTRIM(CONVERT(VARCHAR(50), [Number of Prescriptions]))), '''')) > 0
          AND TRY_CONVERT(INT, [Year]) IS NOT NULL
          AND TRY_CONVERT(INT, [Quarter]) IS NOT NULL
          AND [Product Name] IS NOT NULL;
        ';

        EXEC sys.sp_executesql @sql;
    END

    SET @y = @y + 1;
END;
GO

SELECT COUNT(*) AS MedicaidUtilizationRowCount
FROM MedicaidUtilization;
GO



TRUNCATE TABLE DrugNameMap;
GO

;WITH Base AS
(
    SELECT
        Id,
        GenericName,
        BrandName,
        UPPER(LTRIM(RTRIM(REPLACE(REPLACE(REPLACE(GenericName, ',', ''), '.', ''), '-', ' ')))) AS CleanGeneric,
        UPPER(LTRIM(RTRIM(REPLACE(REPLACE(REPLACE(BrandName, ',', ''), '.', ''), '-', ' ')))) AS CleanBrand
    FROM FirstGenericLaunches
),
Terms AS
(
    SELECT
        Id,
        GenericName,
        BrandName,
        LEFT(CleanBrand, CHARINDEX(' ', CleanBrand + ' ') - 1) AS BrandFirstWord,
        CASE
            WHEN CHARINDEX(' AND ', CleanGeneric) > 0
                THEN LEFT(CleanGeneric, CHARINDEX(' AND ', CleanGeneric) - 1)
            ELSE CleanGeneric
        END AS GenericBeforeAnd
    FROM Base
),
FinalTerms AS
(
    SELECT
        Id,
        GenericName,
        BrandName,
        BrandFirstWord,
        LEFT(GenericBeforeAnd, CHARINDEX(' ', GenericBeforeAnd + ' ') - 1) AS GenericFirstWord
    FROM Terms
)
INSERT INTO DrugNameMap
(
    LaunchId,
    GenericIngredient,
    BrandName,
    ProductRole,
    MatchTerm
)
SELECT
    Id,
    GenericName,
    BrandName,
    'BRAND',
    CASE 
        WHEN LEN(BrandFirstWord) >= 8 THEN LEFT(BrandFirstWord, 8)
        ELSE BrandFirstWord
    END
FROM FinalTerms
WHERE LEN(BrandFirstWord) >= 4

UNION ALL

SELECT
    Id,
    GenericName,
    BrandName,
    'GENERIC',
    CASE 
        WHEN LEN(GenericFirstWord) >= 8 THEN LEFT(GenericFirstWord, 8)
        ELSE GenericFirstWord
    END
FROM FinalTerms
WHERE LEN(GenericFirstWord) >= 4;
GO

SELECT *
FROM DrugNameMap
ORDER BY GenericIngredient, ProductRole;
GO


SELECT
    dm.GenericIngredient,
    dm.BrandName,
    dm.ProductRole,
    dm.MatchTerm,
    mu.DrugName AS MatchedMedicaidProductName,
    COUNT(*) AS MatchedRows,
    COUNT(DISTINCT mu.StateCode) AS MatchedStateCount,
    MIN(CONCAT(mu.Year, '-Q', mu.Quarter)) AS FirstPeriod,
    MAX(CONCAT(mu.Year, '-Q', mu.Quarter)) AS LastPeriod,
    SUM(mu.Prescriptions) AS TotalPrescriptions
FROM DrugNameMap dm
JOIN MedicaidUtilization mu
    ON mu.DrugName LIKE '%' + dm.MatchTerm + '%'
GROUP BY
    dm.GenericIngredient,
    dm.BrandName,
    dm.ProductRole,
    dm.MatchTerm,
    mu.DrugName
ORDER BY
    dm.GenericIngredient,
    dm.ProductRole,
    TotalPrescriptions DESC;
GO


TRUNCATE TABLE QuarterlyMetrics;
GO

;WITH RowMatches AS
(
    SELECT DISTINCT
        dm.LaunchId,
        mu.Id AS UtilizationId,
        dm.ProductRole
    FROM DrugNameMap dm
    JOIN FirstGenericLaunches f
        ON f.Id = dm.LaunchId
    JOIN MedicaidUtilization mu
        ON mu.DrugName LIKE '%' + dm.MatchTerm + '%'
    WHERE
        (mu.Year * 4 + mu.Quarter) >= (YEAR(f.ApprovalDate) * 4 + DATEPART(QUARTER, f.ApprovalDate))
        AND
        (mu.Year * 4 + mu.Quarter) <= (YEAR(f.ApprovalDate) * 4 + DATEPART(QUARTER, f.ApprovalDate) + 12)
),
MoleculeRows AS
(
    SELECT
        rm.LaunchId,
        mu.Id AS UtilizationId,
        mu.Year,
        mu.Quarter,
        mu.StateCode,
        MAX(CASE WHEN rm.ProductRole = 'GENERIC' THEN 1 ELSE 0 END) AS IsGenericRow,
        MAX(mu.Prescriptions) AS Prescriptions
    FROM RowMatches rm
    JOIN MedicaidUtilization mu
        ON mu.Id = rm.UtilizationId
    GROUP BY
        rm.LaunchId,
        mu.Id,
        mu.Year,
        mu.Quarter,
        mu.StateCode
),
StateQuarter AS
(
    SELECT
        LaunchId,
        Year,
        Quarter,
        StateCode,
        SUM(Prescriptions) AS StateMoleculePrescriptions,
        SUM(CASE WHEN IsGenericRow = 1 THEN Prescriptions ELSE 0 END) AS StateGenericPrescriptions,
        MAX(IsGenericRow) AS HasGeneric
    FROM MoleculeRows
    GROUP BY
        LaunchId,
        Year,
        Quarter,
        StateCode
),
RawMetrics AS
(
    SELECT
        f.Id AS LaunchId,
        f.GenericName,
        f.BrandName,
        f.TherapeuticClass,
        sq.Year,
        sq.Quarter,
        ((sq.Year - YEAR(f.ApprovalDate)) * 4 + (sq.Quarter - DATEPART(QUARTER, f.ApprovalDate)) + 1) AS QuarterSinceLaunch,
        COUNT(*) AS ActiveStates,
        SUM(CASE WHEN sq.HasGeneric = 1 THEN 1 ELSE 0 END) AS GenericStates,
        SUM(sq.StateMoleculePrescriptions) AS TotalMoleculePrescriptions,
        SUM(sq.StateGenericPrescriptions) AS TotalGenericPrescriptions,
        SUM(CASE WHEN sq.HasGeneric = 1 THEN sq.StateMoleculePrescriptions ELSE 0 END) AS MoleculePrescriptionsInGenericStates
    FROM StateQuarter sq
    JOIN FirstGenericLaunches f
        ON f.Id = sq.LaunchId
    GROUP BY
        f.Id,
        f.GenericName,
        f.BrandName,
        f.TherapeuticClass,
        f.ApprovalDate,
        sq.Year,
        sq.Quarter
),
FinalMetrics AS
(
    SELECT
        GenericName,
        BrandName,
        TherapeuticClass,
        Year,
        Quarter,
        QuarterSinceLaunch,
        ActiveStates,
        GenericStates,
        TotalGenericPrescriptions,
        TotalMoleculePrescriptions,
        CAST(GenericStates * 100.0 / NULLIF(ActiveStates, 0) AS FLOAT) AS NumericDistribution,
        CAST(MoleculePrescriptionsInGenericStates * 100.0 / NULLIF(TotalMoleculePrescriptions, 0) AS FLOAT) AS WeightedDistribution
    FROM RawMetrics
    WHERE ActiveStates > 0
      AND TotalMoleculePrescriptions > 0
)
INSERT INTO QuarterlyMetrics
(
    GenericName,
    BrandName,
    TherapeuticClass,
    Year,
    Quarter,
    QuarterSinceLaunch,
    NumericDistribution,
    WeightedDistribution,
    AccessGap,
    TotalGenericPrescriptions,
    TotalClassPrescriptions,
    ActiveStates,
    GenericStates
)
SELECT
    GenericName,
    BrandName,
    TherapeuticClass,
    Year,
    Quarter,
    QuarterSinceLaunch,
    NumericDistribution,
    WeightedDistribution,
    WeightedDistribution - NumericDistribution AS AccessGap,
    TotalGenericPrescriptions,
    TotalMoleculePrescriptions,
    ActiveStates,
    GenericStates
FROM FinalMetrics;
GO


SELECT
    GenericName,
    BrandName,
    TherapeuticClass,
    Year,
    Quarter,
    QuarterSinceLaunch,
    ROUND(NumericDistribution, 2) AS ND_Percent,
    ROUND(WeightedDistribution, 2) AS WD_Percent,
    ROUND(AccessGap, 2) AS WD_ND_Gap,
    ActiveStates,
    GenericStates,
    ROUND(TotalGenericPrescriptions, 0) AS GenericPrescriptions,
    ROUND(TotalClassPrescriptions, 0) AS MoleculePrescriptions
FROM QuarterlyMetrics
ORDER BY
    GenericName,
    Year,
    Quarter;
GO


SELECT
    f.GenericName,
    f.BrandName,
    f.TherapeuticClass,
    f.ApprovalDate,
    COUNT(q.Id) AS MetricRows
FROM FirstGenericLaunches f
LEFT JOIN QuarterlyMetrics q
    ON q.GenericName = f.GenericName
   AND q.BrandName = f.BrandName
GROUP BY
    f.GenericName,
    f.BrandName,
    f.TherapeuticClass,
    f.ApprovalDate
HAVING COUNT(q.Id) = 0
ORDER BY f.ApprovalDate;
GO