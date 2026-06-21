using Microsoft.ML.Data;

namespace ModelTraining
{
    public class GenericLaunchData
    {
        [LoadColumn(0)]
        public float QuarterSinceLaunch { get; set; }

        [LoadColumn(1)]
        public float CurrentND { get; set; }

        [LoadColumn(2)]
        public float CurrentWD { get; set; }

        [LoadColumn(3)]
        public float PreviousND { get; set; }

        [LoadColumn(4)]
        public float PreviousWD { get; set; }

        [LoadColumn(5)]
        public float NDGrowth { get; set; }

        [LoadColumn(6)]
        public float WDGrowth { get; set; }

        [LoadColumn(7)]
        public float AccessGap { get; set; }

        [LoadColumn(8)]
        public float TotalGenericPrescriptions { get; set; }

        [LoadColumn(9)]
        public float TotalClassPrescriptions { get; set; }

        [LoadColumn(10)]
        public string AdoptionClass { get; set; }
    }

    public class GenericLaunchPrediction
    {
        [ColumnName("PredictedLabel")]
        public string PredictedAdoptionClass { get; set; }

        public float[] Score { get; set; }
    }
}