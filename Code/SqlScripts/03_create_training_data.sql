/*

Purpose:
Creates ML.NET training data from QuarterlyMetrics.

ML task:
Classify generic launch diffusion as Fast, Medium, or Slow.

Logic:
Uses early launch quarters Q1-Q3 as input features.
Uses Q4 Weighted Distribution as the adoption-class label.

AdoptionClass:
Fast   = Q4 WD >= 80%
Medium = Q4 WD >= 50% and < 80%
Slow   = Q4 WD < 50%
*/

USE GenericLaunchResearch;
GO

TRUNCATE TABLE ModelTrainingData;
GO

;WITH Q AS
(
    SELECT
        GenericName,
        BrandName,
        TherapeuticClass,
        Year,
        Quarter,
        QuarterSinceLaunch,
        NumericDistribution,
        WeightedDistribution,
        LAG(NumericDistribution) OVER
        (
            PARTITION BY GenericName, BrandName
            ORDER BY Year, Quarter
        ) AS PreviousND,
        LAG(WeightedDistribution) OVER
        (
            PARTITION BY GenericName, BrandName
            ORDER BY Year, Quarter
        ) AS PreviousWD,
        AccessGap,
        TotalGenericPrescriptions,
        TotalClassPrescriptions
    FROM QuarterlyMetrics
    WHERE QuarterSinceLaunch BETWEEN 1 AND 4
),
FinalAdoption AS
(
    SELECT
        GenericName,
        BrandName,
        MAX(CASE WHEN QuarterSinceLaunch = 4 THEN WeightedDistribution END) AS WDAtQuarter4
    FROM QuarterlyMetrics
    GROUP BY GenericName, BrandName
    HAVING MAX(CASE WHEN QuarterSinceLaunch = 4 THEN 1 ELSE 0 END) = 1
)
INSERT INTO ModelTrainingData
(
    GenericName,
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



SELECT *
FROM ModelTrainingData
ORDER BY GenericName, QuarterSinceLaunch;
GO



SELECT 
    AdoptionClass,
    COUNT(*) AS TotalRows
FROM ModelTrainingData
GROUP BY AdoptionClass
ORDER BY AdoptionClass;
GO



SELECT COUNT(*) AS TotalTrainingRows
FROM ModelTrainingData;
GO


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
FROM ModelTrainingData
ORDER BY GenericName, QuarterSinceLaunch;
GO