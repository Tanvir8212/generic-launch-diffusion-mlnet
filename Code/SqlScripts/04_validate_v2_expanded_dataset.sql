USE GenericLaunchResearch;
GO

/* ============================================================
   V2 VALIDATION CHECKS AFTER SDUD 2017-2025 EXPANSION
   Purpose:
   - Confirm FDA launch counts
   - Confirm complete Q1-Q4 cases
   - Confirm launch-level adoption-class distribution
   - Identify launches with no metrics
   - Review top Access Gap cases
   - Check duplicate metric rows
   - Check null/bad model values
   ============================================================ */



SELECT
    YEAR(ApprovalDate) AS ApprovalYear,
    COUNT(*) AS LaunchCount
FROM dbo.FirstGenericLaunches
GROUP BY YEAR(ApprovalDate)
ORDER BY ApprovalYear;



SELECT
    COUNT(*) AS FirstGenericLaunchCount
FROM dbo.FirstGenericLaunches;



SELECT
    QuarterSinceLaunch,
    COUNT(*) AS MetricRows,
    COUNT(DISTINCT GenericName + '|' + BrandName) AS DistinctLaunches
FROM dbo.QuarterlyMetrics
GROUP BY QuarterSinceLaunch
ORDER BY QuarterSinceLaunch;



;WITH CompleteQ1Q4 AS
(
    SELECT
        GenericName,
        BrandName,
        COUNT(DISTINCT QuarterSinceLaunch) AS QuarterCount
    FROM dbo.QuarterlyMetrics
    WHERE QuarterSinceLaunch BETWEEN 1 AND 4
    GROUP BY GenericName, BrandName
    HAVING COUNT(DISTINCT QuarterSinceLaunch) = 4
)
SELECT
    COUNT(*) AS CompleteQ1Q4LaunchCases
FROM CompleteQ1Q4;



;WITH Q4Labels AS
(
    SELECT
        GenericName,
        BrandName,
        MAX(CASE WHEN QuarterSinceLaunch = 4 THEN WeightedDistribution END) AS WDAtQuarter4
    FROM dbo.QuarterlyMetrics
    GROUP BY GenericName, BrandName
    HAVING MAX(CASE WHEN QuarterSinceLaunch = 4 THEN 1 ELSE 0 END) = 1
)
SELECT
    CASE
        WHEN WDAtQuarter4 >= 80 THEN 'Fast'
        WHEN WDAtQuarter4 >= 50 THEN 'Medium'
        ELSE 'Slow'
    END AS AdoptionClass,
    COUNT(*) AS LaunchCount,
    CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER () AS DECIMAL(10,2)) AS PercentOfLaunches
FROM Q4Labels
GROUP BY
    CASE
        WHEN WDAtQuarter4 >= 80 THEN 'Fast'
        WHEN WDAtQuarter4 >= 50 THEN 'Medium'
        ELSE 'Slow'
    END
ORDER BY AdoptionClass;



SELECT
    COUNT(*) AS TotalTrainingRows,
    CAST(COUNT(*) / 3.0 AS DECIMAL(10,2)) AS ApproxLaunchCasesFromTrainingRows
FROM dbo.ModelTrainingData;



SELECT
    QuarterSinceLaunch,
    AdoptionClass,
    COUNT(*) AS Row_Count
FROM dbo.ModelTrainingData
GROUP BY QuarterSinceLaunch, AdoptionClass
ORDER BY QuarterSinceLaunch, AdoptionClass;



SELECT
    f.GenericName,
    f.BrandName,
    f.TherapeuticClass,
    f.ApprovalDate,
    COUNT(q.Id) AS MetricRows
FROM dbo.FirstGenericLaunches f
LEFT JOIN dbo.QuarterlyMetrics q
    ON q.GenericName = f.GenericName
    AND q.BrandName = f.BrandName
GROUP BY
    f.GenericName,
    f.BrandName,
    f.TherapeuticClass,
    f.ApprovalDate
HAVING COUNT(q.Id) = 0
ORDER BY f.ApprovalDate;



SELECT TOP 30
    GenericName,
    BrandName,
    TherapeuticClass,
    [Year],
    [Quarter],
    QuarterSinceLaunch,
    ROUND(NumericDistribution, 2) AS ND_Percent,
    ROUND(WeightedDistribution, 2) AS WD_Percent,
    ROUND(AccessGap, 2) AS AccessGap,
    ActiveStates,
    GenericStates,
    ROUND(TotalGenericPrescriptions, 0) AS GenericPrescriptions,
    ROUND(TotalClassPrescriptions, 0) AS MoleculePrescriptions
FROM dbo.QuarterlyMetrics
WHERE QuarterSinceLaunch BETWEEN 1 AND 4
ORDER BY AccessGap DESC;



SELECT TOP 30
    GenericName,
    BrandName,
    TherapeuticClass,
    ROUND(NumericDistribution, 2) AS Q4_ND,
    ROUND(WeightedDistribution, 2) AS Q4_WD,
    ROUND(AccessGap, 2) AS Q4_AccessGap,
    ActiveStates,
    GenericStates,
    ROUND(TotalGenericPrescriptions, 0) AS GenericPrescriptions,
    ROUND(TotalClassPrescriptions, 0) AS MoleculePrescriptions
FROM dbo.QuarterlyMetrics
WHERE QuarterSinceLaunch = 4
ORDER BY WeightedDistribution DESC;



SELECT TOP 50
    GenericName,
    BrandName,
    TherapeuticClass,
    ROUND(NumericDistribution, 2) AS Q4_ND,
    ROUND(WeightedDistribution, 2) AS Q4_WD,
    ROUND(AccessGap, 2) AS Q4_AccessGap,
    ActiveStates,
    GenericStates,
    ROUND(TotalGenericPrescriptions, 0) AS GenericPrescriptions,
    ROUND(TotalClassPrescriptions, 0) AS MoleculePrescriptions
FROM dbo.QuarterlyMetrics
WHERE QuarterSinceLaunch = 4
ORDER BY WeightedDistribution ASC;



SELECT
    ProductRole,
    COUNT(*) AS TermCount
FROM dbo.DrugNameMap
GROUP BY ProductRole
ORDER BY ProductRole;



SELECT
    GenericName,
    BrandName,
    [Year],
    [Quarter],
    QuarterSinceLaunch,
    COUNT(*) AS DuplicateMetricRows
FROM dbo.QuarterlyMetrics
GROUP BY
    GenericName,
    BrandName,
    [Year],
    [Quarter],
    QuarterSinceLaunch
HAVING COUNT(*) > 1
ORDER BY DuplicateMetricRows DESC;



SELECT
    SUM(CASE WHEN CurrentND IS NULL THEN 1 ELSE 0 END) AS NullCurrentND,
    SUM(CASE WHEN CurrentWD IS NULL THEN 1 ELSE 0 END) AS NullCurrentWD,
    SUM(CASE WHEN PreviousND IS NULL THEN 1 ELSE 0 END) AS NullPreviousND,
    SUM(CASE WHEN PreviousWD IS NULL THEN 1 ELSE 0 END) AS NullPreviousWD,
    SUM(CASE WHEN AccessGap IS NULL THEN 1 ELSE 0 END) AS NullAccessGap,
    SUM(CASE WHEN AdoptionClass IS NULL THEN 1 ELSE 0 END) AS NullAdoptionClass
FROM dbo.ModelTrainingData;
GO
