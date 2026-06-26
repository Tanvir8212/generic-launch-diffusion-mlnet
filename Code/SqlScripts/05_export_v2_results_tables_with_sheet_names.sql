USE GenericLaunchResearch;
GO






PRINT 'EXCEL SHEET NAME: dataset_summary_v2';

SELECT 'FDA launch records included after dedupe' AS Metric, COUNT(*) AS Value
FROM dbo.FirstGenericLaunches

UNION ALL

SELECT 'Quarterly ND/WD observations Q1-Q13', COUNT(*)
FROM dbo.QuarterlyMetrics

UNION ALL

SELECT 'First-four-quarter observations Q1-Q4', COUNT(*)
FROM dbo.QuarterlyMetrics
WHERE QuarterSinceLaunch BETWEEN 1 AND 4

UNION ALL

SELECT 'Complete Q1-Q4 launch cases', COUNT(*)
FROM
(
    SELECT GenericName, BrandName
    FROM dbo.QuarterlyMetrics
    WHERE QuarterSinceLaunch BETWEEN 1 AND 4
    GROUP BY GenericName, BrandName
    HAVING COUNT(DISTINCT QuarterSinceLaunch) = 4
) x

UNION ALL

SELECT 'ML.NET training rows Q1-Q3', COUNT(*)
FROM dbo.ModelTrainingData;
GO


/* ============================================================
*/

PRINT 'EXCEL SHEET NAME: fda_launch_counts_v2';

SELECT
    YEAR(ApprovalDate) AS ApprovalYear,
    COUNT(*) AS LaunchCount
FROM dbo.FirstGenericLaunches
GROUP BY YEAR(ApprovalDate)
ORDER BY ApprovalYear;
GO


/* ============================================================
 */

PRINT 'EXCEL SHEET NAME: q_metric_coverage_v2';

SELECT
    QuarterSinceLaunch,
    COUNT(*) AS MetricRows,
    COUNT(DISTINCT GenericName + '|' + BrandName) AS DistinctLaunches
FROM dbo.QuarterlyMetrics
GROUP BY QuarterSinceLaunch
ORDER BY QuarterSinceLaunch;
GO


/* ============================================================
*/

PRINT 'EXCEL SHEET NAME: adoption_class_dist_v2';

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
GO


/* ============================================================
 */

PRINT 'EXCEL SHEET NAME: ml_training_class_v2';

SELECT
    AdoptionClass,
    COUNT(*) AS TrainingRows,
    CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER () AS DECIMAL(10,2)) AS PercentOfTrainingRows
FROM dbo.ModelTrainingData
GROUP BY AdoptionClass
ORDER BY AdoptionClass;
GO


/* ============================================================
*/

PRINT 'EXCEL SHEET NAME: train_test_split_v2';

SELECT
    CASE
        WHEN ApprovalYear BETWEEN 2017 AND 2022 THEN 'Train: 2017-2022'
        WHEN ApprovalYear BETWEEN 2023 AND 2024 THEN 'Test: 2023-2024'
        ELSE 'Other'
    END AS SplitGroup,
    AdoptionClass,
    COUNT(*) AS Row_Count
FROM dbo.ModelTrainingData
GROUP BY
    CASE
        WHEN ApprovalYear BETWEEN 2017 AND 2022 THEN 'Train: 2017-2022'
        WHEN ApprovalYear BETWEEN 2023 AND 2024 THEN 'Test: 2023-2024'
        ELSE 'Other'
    END,
    AdoptionClass
ORDER BY SplitGroup, AdoptionClass;
GO


/* ============================================================
*/

PRINT 'EXCEL SHEET NAME: top_access_gap_cases_v2';

SELECT TOP 30
    GenericName,
    BrandName,
    TherapeuticClass,
    [Year],
    [Quarter],
    QuarterSinceLaunch,
    CAST(ROUND(NumericDistribution, 2) AS DECIMAL(10,2)) AS ND_Percent,
    CAST(ROUND(WeightedDistribution, 2) AS DECIMAL(10,2)) AS WD_Percent,
    CAST(ROUND(AccessGap, 2) AS DECIMAL(10,2)) AS AccessGap,
    ActiveStates,
    GenericStates,
    CAST(ROUND(TotalGenericPrescriptions, 0) AS BIGINT) AS GenericPrescriptions,
    CAST(ROUND(TotalClassPrescriptions, 0) AS BIGINT) AS MoleculePrescriptions
FROM dbo.QuarterlyMetrics
WHERE QuarterSinceLaunch BETWEEN 1 AND 4
ORDER BY AccessGap DESC;
GO


/* ============================================================
*/

PRINT 'EXCEL SHEET NAME: broad_fast_q4_cases_v2';

SELECT TOP 30
    GenericName,
    BrandName,
    TherapeuticClass,
    CAST(ROUND(NumericDistribution, 2) AS DECIMAL(10,2)) AS Q4_ND,
    CAST(ROUND(WeightedDistribution, 2) AS DECIMAL(10,2)) AS Q4_WD,
    CAST(ROUND(AccessGap, 2) AS DECIMAL(10,2)) AS Q4_AccessGap,
    ActiveStates,
    GenericStates,
    CAST(ROUND(TotalGenericPrescriptions, 0) AS BIGINT) AS GenericPrescriptions,
    CAST(ROUND(TotalClassPrescriptions, 0) AS BIGINT) AS MoleculePrescriptions
FROM dbo.QuarterlyMetrics
WHERE QuarterSinceLaunch = 4
ORDER BY WeightedDistribution DESC, NumericDistribution DESC, GenericPrescriptions DESC;
GO


/* ============================================================
*/

PRINT 'EXCEL SHEET NAME: slow_q4_cases_v2';

SELECT TOP 50
    GenericName,
    BrandName,
    TherapeuticClass,
    CAST(ROUND(NumericDistribution, 2) AS DECIMAL(10,2)) AS Q4_ND,
    CAST(ROUND(WeightedDistribution, 2) AS DECIMAL(10,2)) AS Q4_WD,
    CAST(ROUND(AccessGap, 2) AS DECIMAL(10,2)) AS Q4_AccessGap,
    ActiveStates,
    GenericStates,
    CAST(ROUND(TotalGenericPrescriptions, 0) AS BIGINT) AS GenericPrescriptions,
    CAST(ROUND(TotalClassPrescriptions, 0) AS BIGINT) AS MoleculePrescriptions
FROM dbo.QuarterlyMetrics
WHERE QuarterSinceLaunch = 4
ORDER BY WeightedDistribution ASC, NumericDistribution ASC;
GO


/* ============================================================
*/

PRINT 'EXCEL SHEET NAME: time_to_wd80_detail_v2';

;WITH Thresholds AS
(
    SELECT
        GenericName,
        BrandName,
        TherapeuticClass,
        MIN(CASE WHEN WeightedDistribution >= 50 THEN QuarterSinceLaunch END) AS FirstQuarter_WD50,
        MIN(CASE WHEN WeightedDistribution >= 80 THEN QuarterSinceLaunch END) AS FirstQuarter_WD80,
        MAX(CASE WHEN QuarterSinceLaunch = 4 THEN WeightedDistribution END) AS Q4_WD,
        MAX(CASE WHEN QuarterSinceLaunch = 4 THEN NumericDistribution END) AS Q4_ND
    FROM dbo.QuarterlyMetrics
    WHERE QuarterSinceLaunch BETWEEN 1 AND 4
    GROUP BY GenericName, BrandName, TherapeuticClass
)
SELECT
    GenericName,
    BrandName,
    TherapeuticClass,
    FirstQuarter_WD50,
    FirstQuarter_WD80,
    CAST(ROUND(Q4_ND, 2) AS DECIMAL(10,2)) AS Q4_ND,
    CAST(ROUND(Q4_WD, 2) AS DECIMAL(10,2)) AS Q4_WD,
    CASE
        WHEN FirstQuarter_WD80 = 1 THEN 'Reached WD80 in Q1'
        WHEN FirstQuarter_WD80 = 2 THEN 'Reached WD80 in Q2'
        WHEN FirstQuarter_WD80 = 3 THEN 'Reached WD80 in Q3'
        WHEN FirstQuarter_WD80 = 4 THEN 'Reached WD80 in Q4'
        WHEN FirstQuarter_WD80 IS NULL THEN 'Did not reach WD80 by Q4'
    END AS WD80TimingGroup
FROM Thresholds
ORDER BY
    CASE
        WHEN FirstQuarter_WD80 IS NULL THEN 99
        ELSE FirstQuarter_WD80
    END,
    Q4_WD DESC;
GO


/* ============================================================
*/

PRINT 'EXCEL SHEET NAME: time_to_wd80_summary_v2';

;WITH Thresholds AS
(
    SELECT
        GenericName,
        BrandName,
        MIN(CASE WHEN WeightedDistribution >= 80 THEN QuarterSinceLaunch END) AS FirstQuarter_WD80
    FROM dbo.QuarterlyMetrics
    WHERE QuarterSinceLaunch BETWEEN 1 AND 4
    GROUP BY GenericName, BrandName
)
SELECT
    CASE
        WHEN FirstQuarter_WD80 = 1 THEN 'Reached WD80 in Q1'
        WHEN FirstQuarter_WD80 = 2 THEN 'Reached WD80 in Q2'
        WHEN FirstQuarter_WD80 = 3 THEN 'Reached WD80 in Q3'
        WHEN FirstQuarter_WD80 = 4 THEN 'Reached WD80 in Q4'
        WHEN FirstQuarter_WD80 IS NULL THEN 'Did not reach WD80 by Q4'
    END AS WD80TimingGroup,
    COUNT(*) AS LaunchCount,
    CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER () AS DECIMAL(10,2)) AS PercentOfLaunches
FROM Thresholds
GROUP BY
    CASE
        WHEN FirstQuarter_WD80 = 1 THEN 'Reached WD80 in Q1'
        WHEN FirstQuarter_WD80 = 2 THEN 'Reached WD80 in Q2'
        WHEN FirstQuarter_WD80 = 3 THEN 'Reached WD80 in Q3'
        WHEN FirstQuarter_WD80 = 4 THEN 'Reached WD80 in Q4'
        WHEN FirstQuarter_WD80 IS NULL THEN 'Did not reach WD80 by Q4'
    END
ORDER BY
    MIN(CASE
        WHEN FirstQuarter_WD80 = 1 THEN 1
        WHEN FirstQuarter_WD80 = 2 THEN 2
        WHEN FirstQuarter_WD80 = 3 THEN 3
        WHEN FirstQuarter_WD80 = 4 THEN 4
        ELSE 99
    END);
GO


/* ============================================================
*/

PRINT 'EXCEL SHEET NAME: therapeutic_summary_v2';

;WITH Q4 AS
(
    SELECT
        GenericName,
        BrandName,
        TherapeuticClass,
        NumericDistribution AS Q4_ND,
        WeightedDistribution AS Q4_WD
    FROM dbo.QuarterlyMetrics
    WHERE QuarterSinceLaunch = 4
)
SELECT
    TherapeuticClass,
    COUNT(*) AS LaunchCount,
    CAST(ROUND(AVG(Q4_ND), 2) AS DECIMAL(10,2)) AS Mean_Q4_ND,
    CAST(ROUND(AVG(Q4_WD), 2) AS DECIMAL(10,2)) AS Mean_Q4_WD,
    SUM(CASE WHEN Q4_WD >= 80 THEN 1 ELSE 0 END) AS FastLaunches,
    SUM(CASE WHEN Q4_WD >= 50 AND Q4_WD < 80 THEN 1 ELSE 0 END) AS MediumLaunches,
    SUM(CASE WHEN Q4_WD < 50 THEN 1 ELSE 0 END) AS SlowLaunches
FROM Q4
GROUP BY TherapeuticClass
ORDER BY LaunchCount DESC, Mean_Q4_WD DESC;
GO


/* ============================================================
*/

PRINT 'EXCEL SHEET NAME: threshold_sensitivity_v2';

;WITH Q4 AS
(
    SELECT
        GenericName,
        BrandName,
        WeightedDistribution AS Q4_WD
    FROM dbo.QuarterlyMetrics
    WHERE QuarterSinceLaunch = 4
)
SELECT
    'Scheme A: Fast >=80, Medium 50-79.99, Slow <50' AS ThresholdScheme,
    SUM(CASE WHEN Q4_WD >= 80 THEN 1 ELSE 0 END) AS FastCount,
    SUM(CASE WHEN Q4_WD >= 50 AND Q4_WD < 80 THEN 1 ELSE 0 END) AS MediumCount,
    SUM(CASE WHEN Q4_WD < 50 THEN 1 ELSE 0 END) AS SlowCount
FROM Q4

UNION ALL

SELECT
    'Scheme B: Fast >=75, Medium 40-74.99, Slow <40',
    SUM(CASE WHEN Q4_WD >= 75 THEN 1 ELSE 0 END),
    SUM(CASE WHEN Q4_WD >= 40 AND Q4_WD < 75 THEN 1 ELSE 0 END),
    SUM(CASE WHEN Q4_WD < 40 THEN 1 ELSE 0 END)
FROM Q4

UNION ALL

SELECT
    'Scheme C: Fast >=90, Medium 60-89.99, Slow <60',
    SUM(CASE WHEN Q4_WD >= 90 THEN 1 ELSE 0 END),
    SUM(CASE WHEN Q4_WD >= 60 AND Q4_WD < 90 THEN 1 ELSE 0 END),
    SUM(CASE WHEN Q4_WD < 60 THEN 1 ELSE 0 END)
FROM Q4;
GO


/* ============================================================
*/

PRINT 'EXCEL SHEET NAME: no_metric_launches_v2';

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
GO


/* ============================================================
 */

PRINT 'EXCEL SHEET NAME: data_quality_checks_v2';

SELECT
    'Duplicate metric rows' AS CheckName,
    COUNT(*) AS IssueCount
FROM
(
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
) d

UNION ALL

SELECT
    'Null CurrentND in ModelTrainingData',
    COUNT(*)
FROM dbo.ModelTrainingData
WHERE CurrentND IS NULL

UNION ALL

SELECT
    'Null CurrentWD in ModelTrainingData',
    COUNT(*)
FROM dbo.ModelTrainingData
WHERE CurrentWD IS NULL

UNION ALL

SELECT
    'Null AdoptionClass in ModelTrainingData',
    COUNT(*)
FROM dbo.ModelTrainingData
WHERE AdoptionClass IS NULL

UNION ALL

SELECT
    'Null ApprovalYear in ModelTrainingData',
    COUNT(*)
FROM dbo.ModelTrainingData
WHERE ApprovalYear IS NULL;
GO


/* ============================================================
*/

PRINT 'EXCEL SHEET NAME: mlnet_year_validation_v2';

SELECT 'Training years' AS Metric, '2017-2022' AS Value
UNION ALL SELECT 'Test years', '2023-2024'
UNION ALL SELECT 'Training rows', '654'
UNION ALL SELECT 'Test rows', '141'
UNION ALL SELECT 'Training Fast rows', '522'
UNION ALL SELECT 'Training Medium rows', '9'
UNION ALL SELECT 'Training Slow rows', '123'
UNION ALL SELECT 'Test Fast rows', '84'
UNION ALL SELECT 'Test Medium rows', '9'
UNION ALL SELECT 'Test Slow rows', '48'
UNION ALL SELECT 'Micro Accuracy', '90.78%'
UNION ALL SELECT 'Macro Accuracy', '65.08%'
UNION ALL SELECT 'Log Loss', '0.4734'
UNION ALL SELECT 'Fast Precision', '89.89%'
UNION ALL SELECT 'Fast Recall', '95.24%'
UNION ALL SELECT 'Fast F1', '92.49%'
UNION ALL SELECT 'Fast Support', '84'
UNION ALL SELECT 'Medium Precision', '0.00%'
UNION ALL SELECT 'Medium Recall', '0.00%'
UNION ALL SELECT 'Medium F1', '0.00%'
UNION ALL SELECT 'Medium Support', '9'
UNION ALL SELECT 'Slow Precision', '92.31%'
UNION ALL SELECT 'Slow Recall', '100.00%'
UNION ALL SELECT 'Slow F1', '96.00%'
UNION ALL SELECT 'Slow Support', '48';
GO


/* ============================================================
*/

PRINT 'EXCEL SHEET NAME: confusion_matrix_v2';

SELECT 'Fast' AS ActualClass, 80 AS PredictedFast, 0 AS PredictedMedium, 4 AS PredictedSlow
UNION ALL SELECT 'Medium', 9, 0, 0
UNION ALL SELECT 'Slow', 0, 0, 48;
GO
