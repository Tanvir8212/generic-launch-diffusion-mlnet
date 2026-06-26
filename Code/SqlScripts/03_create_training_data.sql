/* 
Purpose:
Creates ML.NET training data from QuarterlyMetrics.

ML task:
Classify generic launch diffusion as Fast, Medium, or Slow.

Logic:
- Uses early launch quarters Q1-Q3 as input feature rows.
- Uses Q4 Weighted Distribution as the adoption-class label.
- Keeps BrandName in ModelTrainingData for audit/reproducibility.
- BrandName is NOT used as an ML feature.

AdoptionClass:
Fast   = Q4 WD >= 80%
Medium = Q4 WD >= 50% and < 80%
Slow   = Q4 WD < 50%
*/

USE GenericLaunchResearch;
GO

/* Add BrandName column if missing */
IF COL_LENGTH('dbo.ModelTrainingData', 'BrandName') IS NULL
BEGIN
    ALTER TABLE dbo.ModelTrainingData
    ADD BrandName NVARCHAR(255) NULL;
END;
GO

TRUNCATE TABLE dbo.ModelTrainingData;
GO

;WITH Q AS
(
    SELECT
        GenericName,
        BrandName,
        TherapeuticClass,
        [Year],
        [Quarter],
        QuarterSinceLaunch,
        NumericDistribution,
        WeightedDistribution,
        LAG(NumericDistribution) OVER
        (
            PARTITION BY GenericName, BrandName
            ORDER BY [Year], [Quarter]
        ) AS PreviousND,
        LAG(WeightedDistribution) OVER
        (
            PARTITION BY GenericName, BrandName
            ORDER BY [Year], [Quarter]
        ) AS PreviousWD,
        AccessGap,
        TotalGenericPrescriptions,
        TotalClassPrescriptions
    FROM dbo.QuarterlyMetrics
    WHERE QuarterSinceLaunch BETWEEN 1 AND 4
),
FinalAdoption AS
(
    SELECT
        GenericName,
        BrandName,
        MAX(CASE WHEN QuarterSinceLaunch = 4 THEN WeightedDistribution END) AS WDAtQuarter4
    FROM dbo.QuarterlyMetrics
    GROUP BY GenericName, BrandName
    HAVING MAX(CASE WHEN QuarterSinceLaunch = 4 THEN 1 ELSE 0 END) = 1
)
INSERT INTO dbo.ModelTrainingData
(
    GenericName,
    BrandName,
    TherapeuticClass,
    QuarterSinceLaunch,
    CurrentND,
    CurrentWD,
    PreviousND,
    PreviousWD,
    NDGrowth,
    WDGrowth,
    AccessGap,
    TotalGenericPrescriptions,
    TotalClassPrescriptions,
    AdoptionClass
)
SELECT
    q.GenericName,
    q.BrandName,
    q.TherapeuticClass,
    q.QuarterSinceLaunch,
    q.NumericDistribution AS CurrentND,
    q.WeightedDistribution AS CurrentWD,
    ISNULL(q.PreviousND, 0) AS PreviousND,
    ISNULL(q.PreviousWD, 0) AS PreviousWD,
    q.NumericDistribution - ISNULL(q.PreviousND, 0) AS NDGrowth,
    q.WeightedDistribution - ISNULL(q.PreviousWD, 0) AS WDGrowth,
    q.AccessGap,
    q.TotalGenericPrescriptions,
    q.TotalClassPrescriptions,
    CASE
        WHEN fa.WDAtQuarter4 >= 80 THEN 'Fast'
        WHEN fa.WDAtQuarter4 >= 50 THEN 'Medium'
        ELSE 'Slow'
    END AS AdoptionClass
FROM Q q
JOIN FinalAdoption fa
    ON fa.GenericName = q.GenericName
    AND fa.BrandName = q.BrandName
WHERE q.QuarterSinceLaunch BETWEEN 1 AND 3;
GO

/* Audit view */
SELECT TOP 50
    GenericName,
    BrandName,
    TherapeuticClass,
    QuarterSinceLaunch,
    CurrentND,
    CurrentWD,
    PreviousND,
    PreviousWD,
    NDGrowth,
    WDGrowth,
    AccessGap,
    TotalGenericPrescriptions,
    TotalClassPrescriptions,
    AdoptionClass
FROM dbo.ModelTrainingData
ORDER BY GenericName, BrandName, QuarterSinceLaunch;
GO

/* Class distribution */
SELECT
    AdoptionClass,
    COUNT(*) AS TotalRows
FROM dbo.ModelTrainingData
GROUP BY AdoptionClass
ORDER BY AdoptionClass;
GO

/* Total training rows */
SELECT
    COUNT(*) AS TotalTrainingRows
FROM dbo.ModelTrainingData;
GO

/* 
IMPORTANT:
Use this final SELECT when exporting model_training.csv for ML.NET.
Do NOT include GenericName, BrandName, or TherapeuticClass in the ML CSV.
Your current GenericLaunchData.cs expects exactly these 11 columns.
*/

SELECT
    QuarterSinceLaunch,
    CurrentND,
    CurrentWD,
    PreviousND,
    PreviousWD,
    NDGrowth,
    WDGrowth,
    AccessGap,
    TotalGenericPrescriptions,
    TotalClassPrescriptions,
    AdoptionClass
FROM dbo.ModelTrainingData
ORDER BY GenericName, BrandName, QuarterSinceLaunch;
GO