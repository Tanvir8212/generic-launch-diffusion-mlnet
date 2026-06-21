/* 

Project:
Which Pharmacies Get Generics First After Launch?
An ML.NET-Based Forecasting Framework for Generic Drug Diffusion and Access Inequality

Purpose:
Creates the main SQL Server database and final research tables...

Note:
Staging tables such as Stg_SDUD_2021, Stg_SDUD_2022, etc. are imported manually using SSMS Import Flat File.
*/

USE master;
GO

IF DB_ID('GenericLaunchResearch') IS NULL
BEGIN
    CREATE DATABASE GenericLaunchResearch;
END;
GO

USE GenericLaunchResearch;
GO

IF OBJECT_ID('dbo.FirstGenericLaunches', 'U') IS NULL
BEGIN
    CREATE TABLE FirstGenericLaunches (
        Id INT IDENTITY(1,1) PRIMARY KEY,
        GenericName NVARCHAR(300),
        BrandName NVARCHAR(300),
        ApprovalDate DATE,
        TherapeuticClass NVARCHAR(200)
    );
END;
GO

IF OBJECT_ID('dbo.MedicaidUtilization', 'U') IS NULL
BEGIN
    CREATE TABLE MedicaidUtilization (
        Id BIGINT IDENTITY(1,1) PRIMARY KEY,
        Year INT,
        Quarter INT,
        StateCode NVARCHAR(20),
        DrugName NVARCHAR(300),
        NDC NVARCHAR(50),
        Prescriptions FLOAT,
        ReimbursedAmount FLOAT
    );
END;
GO

IF OBJECT_ID('dbo.QuarterlyMetrics', 'U') IS NULL
BEGIN
    CREATE TABLE QuarterlyMetrics (
        Id BIGINT IDENTITY(1,1) PRIMARY KEY,
        GenericName NVARCHAR(300),
        BrandName NVARCHAR(300),
        TherapeuticClass NVARCHAR(200),
        Year INT,
        Quarter INT,
        QuarterSinceLaunch INT,
        NumericDistribution FLOAT,
        WeightedDistribution FLOAT,
        AccessGap FLOAT,
        TotalGenericPrescriptions FLOAT,
        TotalClassPrescriptions FLOAT,
        ActiveStates INT,
        GenericStates INT
    );
END;
GO

IF OBJECT_ID('dbo.ModelTrainingData', 'U') IS NULL
BEGIN
    CREATE TABLE ModelTrainingData (
        Id BIGINT IDENTITY(1,1) PRIMARY KEY,
        GenericName NVARCHAR(300),
        TherapeuticClass NVARCHAR(200),
        QuarterSinceLaunch INT,
        CurrentND FLOAT,
        CurrentWD FLOAT,
        PreviousND FLOAT,
        PreviousWD FLOAT,
        NDGrowth FLOAT,
        WDGrowth FLOAT,
        AccessGap FLOAT,
        TotalGenericPrescriptions FLOAT,
        TotalClassPrescriptions FLOAT,
        AdoptionClass NVARCHAR(50)
    );
END;
GO

IF OBJECT_ID('dbo.DrugNameMap', 'U') IS NULL
BEGIN
    CREATE TABLE DrugNameMap
    (
        Id INT IDENTITY(1,1) PRIMARY KEY,
        LaunchId INT,
        GenericIngredient NVARCHAR(300),
        BrandName NVARCHAR(300),
        ProductRole NVARCHAR(50),
        MatchTerm NVARCHAR(100)
    );
END;
GO

SELECT 'Tables created successfully.' AS Status;
GO