using Microsoft.ML;
using System;
using System.IO;
using System.Linq;

namespace ModelTraining
{
    internal class Program
    {
        static void Main(string[] args)
        {
            string trainDataPath = @"D:\Research\GenericLaunchDiffusion\Data\model_training_train_2017_2022.csv";
            string testDataPath = @"D:\Research\GenericLaunchDiffusion\Data\model_training_test_2023_2024.csv";
            string modelPath = @"D:\Research\GenericLaunchDiffusion\Results\generic_launch_model_year_split.zip";

            Directory.CreateDirectory(@"D:\Research\GenericLaunchDiffusion\Results");

            if (!File.Exists(trainDataPath))
            {
                Console.WriteLine("Train CSV not found:");
                Console.WriteLine(trainDataPath);
                return;
            }

            if (!File.Exists(testDataPath))
            {
                Console.WriteLine("Test CSV not found:");
                Console.WriteLine(testDataPath);
                return;
            }

            PrintCsvSummary("Training", trainDataPath);
            PrintCsvSummary("Test", testDataPath);

            var mlContext = new MLContext(seed: 1);

            var trainData = mlContext.Data.LoadFromTextFile<GenericLaunchData>(
                path: trainDataPath,
                hasHeader: true,
                separatorChar: ',');

            var testData = mlContext.Data.LoadFromTextFile<GenericLaunchData>(
                path: testDataPath,
                hasHeader: true,
                separatorChar: ',');

            var pipeline = mlContext.Transforms.Conversion.MapValueToKey(
                    outputColumnName: "Label",
                    inputColumnName: nameof(GenericLaunchData.AdoptionClass))
                .Append(mlContext.Transforms.Concatenate(
                    "Features",
                    nameof(GenericLaunchData.QuarterSinceLaunch),
                    nameof(GenericLaunchData.CurrentND),
                    nameof(GenericLaunchData.CurrentWD),
                    nameof(GenericLaunchData.PreviousND),
                    nameof(GenericLaunchData.PreviousWD),
                    nameof(GenericLaunchData.NDGrowth),
                    nameof(GenericLaunchData.WDGrowth),
                    nameof(GenericLaunchData.AccessGap),
                    nameof(GenericLaunchData.TotalGenericPrescriptions),
                    nameof(GenericLaunchData.TotalClassPrescriptions)))
                .Append(mlContext.Transforms.NormalizeMinMax("Features"))
                .Append(mlContext.MulticlassClassification.Trainers.SdcaMaximumEntropy(
                    labelColumnName: "Label",
                    featureColumnName: "Features"))
                .Append(mlContext.Transforms.Conversion.MapKeyToValue(
                    outputColumnName: "PredictedLabel",
                    inputColumnName: "PredictedLabel"));

            Console.WriteLine();
            Console.WriteLine("Training year-based model...");
            Console.WriteLine("Train years: 2017-2022");
            Console.WriteLine("Test years : 2023-2024");

            var model = pipeline.Fit(trainData);
            var predictions = model.Transform(testData);

            var metrics = mlContext.MulticlassClassification.Evaluate(
                predictions,
                labelColumnName: "Label",
                predictedLabelColumnName: "PredictedLabel");

            Console.WriteLine();
            Console.WriteLine("ML.NET Generic Launch Diffusion Model");
            Console.WriteLine("Year-Based Validation");
            Console.WriteLine("------------------------------------");
            Console.WriteLine("Micro Accuracy: " + metrics.MicroAccuracy.ToString("P2"));
            Console.WriteLine("Macro Accuracy: " + metrics.MacroAccuracy.ToString("P2"));
            Console.WriteLine("Log Loss: " + metrics.LogLoss.ToString("F4"));

            PrintConfusionMatrixAndPerClassMetrics(mlContext, predictions);

            mlContext.Model.Save(model, trainData.Schema, modelPath);

            Console.WriteLine();
            Console.WriteLine("Model saved to: " + modelPath);

            Console.WriteLine();
            Console.WriteLine("Example prediction:");

            var predictionEngine = mlContext.Model.CreatePredictionEngine<GenericLaunchData, GenericLaunchPrediction>(model);

            var sample = new GenericLaunchData
            {
                QuarterSinceLaunch = 2,
                CurrentND = 30,
                CurrentWD = 65,
                PreviousND = 12,
                PreviousWD = 35,
                NDGrowth = 18,
                WDGrowth = 30,
                AccessGap = 35,
                TotalGenericPrescriptions = 5000,
                TotalClassPrescriptions = 50000
            };

            var prediction = predictionEngine.Predict(sample);
            Console.WriteLine("Predicted adoption class: " + prediction.PredictedAdoptionClass);
        }

        static void PrintCsvSummary(string name, string path)
        {
            var rows = File.ReadAllLines(path)
                .Skip(1)
                .Where(r => !string.IsNullOrWhiteSpace(r))
                .ToList();

            Console.WriteLine();
            Console.WriteLine(name + " rows found: " + rows.Count);

            var labels = rows
                .Select(r => r.Split(',').Last().Trim())
                .GroupBy(x => x)
                .OrderBy(x => x.Key)
                .ToList();

            Console.WriteLine(name + " adoption classes:");

            foreach (var label in labels)
            {
                Console.WriteLine("- " + label.Key + ": " + label.Count());
            }
        }

        static void PrintConfusionMatrixAndPerClassMetrics(MLContext mlContext, IDataView predictions)
        {
            var predictionRows = mlContext.Data.CreateEnumerable<PredictionWithLabel>(
                predictions,
                reuseRowObject: false
            ).ToList();

            var classNames = predictionRows
                .Select(r => r.AdoptionClass)
                .Union(predictionRows.Select(r => r.PredictedAdoptionClass))
                .Where(x => !string.IsNullOrWhiteSpace(x))
                .Distinct()
                .OrderBy(x => x)
                .ToList();

            Console.WriteLine();
            Console.WriteLine("Confusion Matrix");
            Console.WriteLine("----------------");

            Console.Write("Actual \\ Predicted".PadRight(22));

            foreach (var predictedClass in classNames)
            {
                Console.Write(predictedClass.PadRight(12));
            }

            Console.WriteLine();

            foreach (var actualClass in classNames)
            {
                Console.Write(actualClass.PadRight(22));

                foreach (var predictedClass in classNames)
                {
                    int count = predictionRows.Count(r =>
                        r.AdoptionClass == actualClass &&
                        r.PredictedAdoptionClass == predictedClass);

                    Console.Write(count.ToString().PadRight(12));
                }

                Console.WriteLine();
            }

            Console.WriteLine();
            Console.WriteLine("Per-Class Metrics");
            Console.WriteLine("-----------------");
            Console.WriteLine(
                "Class".PadRight(12) +
                "Precision".PadRight(14) +
                "Recall".PadRight(14) +
                "F1".PadRight(14) +
                "Support"
            );

            foreach (var className in classNames)
            {
                int truePositive = predictionRows.Count(r =>
                    r.AdoptionClass == className &&
                    r.PredictedAdoptionClass == className);

                int falsePositive = predictionRows.Count(r =>
                    r.AdoptionClass != className &&
                    r.PredictedAdoptionClass == className);

                int falseNegative = predictionRows.Count(r =>
                    r.AdoptionClass == className &&
                    r.PredictedAdoptionClass != className);

                int support = predictionRows.Count(r =>
                    r.AdoptionClass == className);

                double precision = (truePositive + falsePositive) == 0
                    ? 0
                    : (double)truePositive / (truePositive + falsePositive);

                double recall = (truePositive + falseNegative) == 0
                    ? 0
                    : (double)truePositive / (truePositive + falseNegative);

                double f1 = (precision + recall) == 0
                    ? 0
                    : 2 * precision * recall / (precision + recall);

                Console.WriteLine(
                    className.PadRight(12) +
                    precision.ToString("P2").PadRight(14) +
                    recall.ToString("P2").PadRight(14) +
                    f1.ToString("P2").PadRight(14) +
                    support
                );
            }


            Console.WriteLine("Press Enter to end");
            Console.ReadLine();
        }
    }
}
