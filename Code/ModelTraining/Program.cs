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
            string dataPath = @"D:\Research\GenericLaunchDiffusion\Data\model_training.csv";
            string modelPath = @"D:\Research\GenericLaunchDiffusion\Results\generic_launch_model.zip";

            Directory.CreateDirectory(@"D:\Research\GenericLaunchDiffusion\Results");

            if (!File.Exists(dataPath))
            {
                Console.WriteLine("Training CSV not found:");
                Console.WriteLine(dataPath);
                return;
            }

            var rows = File.ReadAllLines(dataPath).Skip(1).ToList();

            Console.WriteLine("Training rows found: " + rows.Count);

            var labels = rows
                .Where(r => !string.IsNullOrWhiteSpace(r))
                .Select(r => r.Split(',').Last().Trim())
                .Distinct()
                .ToList();

            Console.WriteLine("Adoption classes found:");
            foreach (var label in labels)
            {
                Console.WriteLine("- " + label);
            }

            if (rows.Count < 10)
            {
                Console.WriteLine();
                Console.WriteLine("WARNING: Very small dataset. Good for pipeline testing, not final research.");
            }

            if (labels.Count < 2)
            {
                Console.WriteLine();
                Console.WriteLine("ERROR: Only one adoption class found.");
                Console.WriteLine("ML classification needs at least two classes, for example Fast and Slow.");
                Console.WriteLine("Add more generic launches or adjust thresholds later.");
                return;
            }

            var mlContext = new MLContext(seed: 1);

            var data = mlContext.Data.LoadFromTextFile<GenericLaunchData>(
                path: dataPath,
                hasHeader: true,
                separatorChar: ',');

            var split = mlContext.Data.TrainTestSplit(data, testFraction: 0.25);

            var pipeline =
                mlContext.Transforms.Conversion.MapValueToKey(
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
            Console.WriteLine("Training model...");

            var model = pipeline.Fit(split.TrainSet);

            var predictions = model.Transform(split.TestSet);

            var metrics = mlContext.MulticlassClassification.Evaluate(
                predictions,
                labelColumnName: "Label",
                predictedLabelColumnName: "PredictedLabel");

            Console.WriteLine();
            Console.WriteLine("ML.NET Generic Launch Diffusion Model");
            Console.WriteLine("------------------------------------");
            Console.WriteLine("Micro Accuracy: " + metrics.MicroAccuracy.ToString("P2"));
            Console.WriteLine("Macro Accuracy: " + metrics.MacroAccuracy.ToString("P2"));
            Console.WriteLine("Log Loss: " + metrics.LogLoss.ToString("F4"));

            mlContext.Model.Save(model, split.TrainSet.Schema, modelPath);

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

            Console.WriteLine();
            Console.WriteLine("Press ENTER to close...");
            Console.ReadLine();
        }
    }
}