library(caret)
library(tidyverse)

# 2. DOWNLOAD DATASET (German Credit Dataset)
url <- "https://raw.githubusercontent.com/jbrownlee/Datasets/master/german.csv"
credit_data <- read_csv(url, col_names = FALSE)

# 3. PIPELINE PREPROCESSING & DATA CLEANING
# Menyelaraskan indeks kolom 'X' bawaan R parser ke nama variabel audit substantif
credit_clean <- credit_data %>% 
  select(X1, X2, X5, X9, X21) %>% 
  rename(
    Savings_Status = X1,
    Duration_Months = X2,
    Credit_Amount = X5,
    Personal_Status_Gender = X9,
    Credit_Risk = X21
  ) %>% 
  mutate(
    # Mengubah target menjadi binary factor (0 = Bad Credit, 1 = Good Credit)
    Credit_Risk = as.factor(ifelse(Credit_Risk == 1, 1, 0)),
    # Isolasi Atribut Terproteksi: Menyederhanakan kode fitur X9 menjadi Gender
    # Kode 'A92' dan 'A95' dalam dokumentasi asli mengindikasikan Perempuan (Female)
    Gender = as.factor(ifelse(Personal_Status_Gender %in% c("A92", "A95"), "Female", "Male"))
  )

# 4. PEMBAGIAN DATASET (Data Partition 80:20)
set.seed(42)
training_index <- createDataPartition(credit_clean$Credit_Risk, p = 0.8, list = FALSE)
train_set <- credit_clean[training_index, ]
test_set <- credit_clean[-training_index, ]

# 5. PEMODELAN AI (Logistic Regression Classifier)
# Catatan Tata Kelola: Atribut 'Gender' sengaja DIBUANG dari rumus regresi 
# untuk menguji apakah model tetap bisa menyerap bias secara tidak langsung (proxy bias).
model <- glm(Credit_Risk ~ Savings_Status + Duration_Months + Credit_Amount, 
             data = train_set, family = binomial)

# 6. SIMULASI PREDIKSI (Automated Decision Making pada Test Set)
test_set$Prediction_Prob <- predict(model, newdata = test_set, type = "response")
test_set$Predicted_Class <- as.factor(ifelse(test_set$Prediction_Prob > 0.5, 1, 0))

# 7. KONSOLIDASI DATA UNTUK PIPELINE AUDIT
data_audit <- data.frame(
  predictions = test_set$Predicted_Class,
  labels = test_set$Credit_Risk,
  protected = test_set$Gender
)

# 8. KALKULASI MANDIRI METRIK KEPATUHAN (Disparate Impact Ratio)
audit_summary <- data_audit %>%
  group_by(protected, predictions) %>%
  tally() %>%
  group_by(protected) %>%
  mutate(Total_Group = sum(n),
         Selection_Rate = n / Total_Group) %>%
  filter(predictions == 1) # Mengambil kelompok yang sukses mendapat persetujuan kredit

# Ekstraksi otomatis nilai Selection Rate untuk masing-masing kelompok demografi
rate_female <- audit_summary$Selection_Rate[audit_summary$protected == "Female"]
rate_male <- audit_summary$Selection_Rate[audit_summary$protected == "Male"]

# Rumus Matematika Keadilan: S-Rate Kelompok Terproteksi / S-Rate Kelompok Mayoritas
disparate_impact_ratio <- rate_female / rate_male

# 9. OUTPUT EVALUASI TATA KELOLA & VALIDASI REGULASI (80% RULE METRIC)
cat("\n==================================================================\n")
cat("          LAPORAN HASIL AUDIT KEPATUHAN ALGORITMA (AIA)           \n")
cat("==================================================================\n")
print(audit_summary)
cat("\n------------------------------------------------------------------\n")
cat("Disparate Impact Ratio (Keadilan Gender):", round(disparate_impact_ratio, 4), "\n")
cat("------------------------------------------------------------------\n")

# Evaluasi kepatuhan berdasarkan ambang batas standar industri (Adopsi Standar US EEOC & NIST)
if (disparate_impact_ratio < 0.80) {
  cat("STATUS: [GAGAL KEPATUHAN / NON-COMPLIANT]\n")
  cat("RISIKO: Terdeteksi Dampak Merugikan (Disparate Impact) berupa BIAS SISTEMIK\n")
  cat("        yang merugikan pelamar Perempuan (Female).\n")
  cat("REKOMENDASI MITIGASI (NIST AI RMF):\n")
  cat("1. Lakukan re-weighting/oversampling pada training data sebelum model dirilis.\n")
  cat("2. Batalkan keputusan otomatis mutlak. Wajibkan fungsi peninjauan ulang\n")
  cat("   oleh analis manusia (Human-in-the-Loop) berdasarkan mandat UU PDP.\n")
} else {
  cat("STATUS: [LOLOS KEPATUHAN / COMPLIANT]\n")
  cat("KESIMPULAN: Model AI memenuhi standar kesetaraan demografis (Demographic Parity).\n")
}
cat("==================================================================\n")

# 10. VISUALISASI GRAFIK AUDIT MANDIRI
# Membuat plot ringkas perbandingan Selection Rate untuk laporan visual
ggplot(audit_summary, aes(x = protected, y = Selection_Rate, fill = protected)) +
  geom_bar(stat = "identity", width = 0.5, color = "#333333") +
  geom_hline(yintercept = rate_male * 0.8, linetype = "dashed", color = "red", size = 1) +
  scale_fill_manual(values = c("Female" = "#A80000", "Male" = "#333333")) +
  labs(
    title = "Audit Keadilan Algoritma: Tingkat Persetujuan Kredit Lintas Gender",
    subtitle = "Garis putus-putus merah menandakan batas minimum kepatuhan bias (80% Rule)",
    x = "Kelompok Demografi (Gender)",
    y = "Tingkat Kelayakan Diterima (Selection Rate)"
  ) +
  theme_minimal() +
  theme(legend.position = "none")