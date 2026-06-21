using Microsoft.Data.SqlClient;
using System;
using System.Globalization;
using System.IO;
using System.Text;

namespace DataExport
{
    internal class Program
    {
        static void Main(string[] args)
        {
            string connectionString =
               @"Server=localhost;Database=GenericLaunchResearch;Trusted_Connection=True;TrustServerCertificate=True;";

            string outputPath = @"D:\Research\GenericLaunchDiffusion\Data\model_training.csv";

            string outputFolder = Path.GetDirectoryName(outputPath);

            if (!Directory.Exists(outputFolder))
            {
                Directory.CreateDirectory(outputFolder);
            }

            string query = @"
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
";

            StringBuilder csv = new StringBuilder();

            csv.AppendLine("QuarterSinceLaunch,CurrentND,CurrentWD,PreviousND,PreviousWD,NDGrowth,WDGrowth,AccessGap,TotalGenericPrescriptions,TotalClassPrescriptions,AdoptionClass");

            using (SqlConnection connection = new SqlConnection(connectionString))
            {
                connection.Open();

                using (SqlCommand command = new SqlCommand(query, connection))
                using (SqlDataReader reader = command.ExecuteReader())
                {
                    while (reader.Read())
                    {
                        string adoptionClass = "";

                        if (reader["AdoptionClass"] != DBNull.Value)
                        {
                            adoptionClass = reader["AdoptionClass"].ToString().Trim();
                        }

                        string line = string.Join(",",
                            ToCsvNumber(reader["QuarterSinceLaunch"]),
                            ToCsvNumber(reader["CurrentND"]),
                            ToCsvNumber(reader["CurrentWD"]),
                            ToCsvNumber(reader["PreviousND"]),
                            ToCsvNumber(reader["PreviousWD"]),
                            ToCsvNumber(reader["NDGrowth"]),
                            ToCsvNumber(reader["WDGrowth"]),
                            ToCsvNumber(reader["AccessGap"]),
                            ToCsvNumber(reader["TotalGenericPrescriptions"]),
                            ToCsvNumber(reader["TotalClassPrescriptions"]),
                            adoptionClass
                        );

                        csv.AppendLine(line);
                    }
                }
            }

            File.WriteAllText(outputPath, csv.ToString());

            Console.WriteLine("CSV export completed successfully.");
            Console.WriteLine(outputPath);
        }

        static string ToCsvNumber(object value)
        {
            if (value == null || value == DBNull.Value)
            {
                return "0";
            }

            return Convert.ToDouble(value).ToString(CultureInfo.InvariantCulture);
        }
    }
}