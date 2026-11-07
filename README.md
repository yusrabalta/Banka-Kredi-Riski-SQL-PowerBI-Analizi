#  Bankacılık Kredi Riski ve Portföy Performans Analizi (Excel | MS SQL | Power BI)

Bu projede, **32.500+ gerçek bireysel kredi başvurusunu** kapsayan veri seti üzerinde; **MS Excel**, **MS SQL Server (T-SQL)** ve **Power BI (DAX)** araçları kullanılarak uçtan uca bir kredi temerrüt (default) risk analizi ve karar destek panosu (Dashboard) geliştirilmiştir.


# Projenin Amacı
Bankanın kredi portföyündeki temerrüt (batık kredi) oranını etkileyen temel demografik ve finansal faktörleri belirlemek, kredi/gelir oranı (DTI) için kritik kırılma eşiklerini tespit etmek ve kredi tahsis politikası limit aşımlarının portföy riskine etkisini ölçmektir.


##  Kullanılan Araçlar ve Uygulanan Adımlar

### 1. MS Excel (Veri Ön İnceleme & Kalite Kontrolü)
* Ham CSV verisinin sütun yapılandırması, lokalizasyon kaynaklı ondalık veri tipi kontrolleri ve mantıksal aykırı değer (outlier) tespiti gerçekleştirildi.

### 2. MS SQL Server (Veri Temizliği, Modelleme & İleri Analitik)
* **Veri Temizliği (`DELETE`, `UPDATE`, `ALTER TABLE`):** Mantıksal aykırı gözlemler (yaş > 100, çalışma süresi > 60 yıl) temizlendi ve veri tipleri (`FLOAT`) standartlaştırıldı.
* **Kredi Amacı & Fiyatlama Analizi (`GROUP BY`, `AVG`, `SUM`):** Kredi kullanım amaçlarına göre batık oranları ve ortalama faiz oranları karşılaştırıldı.
* **Gelir Yükü Segmentasyonu (`CASE WHEN`):** Çekilen kredinin yıllık gelire oranı (`loan_percent_income`) 4 risk segmentine ayrılarak kırılma noktası analiz edildi.
* **İlişkisel Modelleme ve Politika Uyum Analizi (`CREATE TABLE`, `INNER JOIN`):** Kredi derecelerine (`A-G`) göre banka politika limitlerini içeren ikinci bir referans tablosu (`BankaRiskPolitikasi`) oluşturularak limit aşımı (`İHLAL` vs `UYGUN`) analizleri yapıldı.
* **İstatistiksel Anomali Tespiti (`WITH CTE`, `OVER PARTITION BY`, `STDEV`):** Pencere fonksiyonları kullanılarak her müşterinin kendi kredi amacı grubuna göre **Z-Skoru ($Z > 2.5$)** hesaplandı ve uç kredi talepleri tespit edildi.
* **Raporlama Mimarisi (`CREATE VIEW`):** Tüm analiz çıktıları `vw_BankaRiskAnalizi` görünümünde birleştirilerek canlı olarak Power BI'a aktarıldı.

### 3. Power BI & DAX (Görselleştirme & Karar Destek Panosu)
* `COUNTROWS`, `CALCULATE` ve `DIVIDE` DAX fonksiyonlarıyla dinamik KPI ölçüleri (`Toplam Başvuru`, `Batık Kredi Sayısı`, `Batık Oranı (%)`) oluşturuldu.
* Yaş grubu ve ev mülkiyeti kırılımlarına göre interaktif filtreleme sunan yönetici panosu tasarlandı.


## Temel Bulgular (Key Insights)
1. **Kredi Amacı ve Fiyatlama Uyumsuzluğu:** En yüksek batık oranı **%28,59** ile *Borç Kapatma (Debt Consolidation)* ve **%26,70** ile *Sağlık (Medical)* kredilerinde görülürken, en düşük risk **%14,82** ile *Girişim (Venture)* kredilerindedir. Buna rağmen tüm gruplarda ortalama faiz oranının (~%11) sabit kalması, risk odaklı fiyatlama (risk-based pricing) ihtiyacı olduğunu göstermektedir.
2. **%30 Gelir Yükü Kırılma Noktası (DTI Cut-off):** Çekilen kredinin yıllık gelire oranı **%30 eşiğini** aştığı anda, batık oranı **%19,17'den %63,81'e (3,3 katına)** sıçramaktadır.
3. **Politika Limiti Etkisi:** En güvenilir kredi notuna (`A - Prime`) sahip müşterilerde dahi, gelir/kredi politika limiti aşıldığında batık oranı **%7,17'den %63,89'a** yükselmektedir.
4. **Z-Skoru Anomali Tespiti:** Kendi kredi amacı ortalamasından 4 standart sapma ($Z = 4,13$) yukarıda kredi çeken (35.000$) ve yıllık geliri 80.000$ altında kalan müşterilerin **%100'ünün** temerrüde düştüğü tespit edilmiştir.


## 📂 Proje Dosyaları
* `Banka_Risk_Analizi_SQL_Kodlari.sql`: Veri temizleme, tablo oluşturma, JOIN, Window Functions ve VIEW oluşturma sorgularının tamamı.
* `Banka_Kredi_Risk_Raporu.pdf`: Power BI Dashboard ekran çıktısı.
* `Banka_Kredi_Risk_Raporu.pbix`: İnteraktif Power BI rapor dosyası.
* `credit_risk_dataset.csv`: Analizde kullanılan ham veri seti.

---

##  Veri Kaynağı ve Metodoloji Notu (Data Source)
Bu çalışmada açık kaynaklı **[Kaggle - Credit Risk Dataset](https://www.kaggle.com/datasets/laotse/credit-risk-dataset)** (32.581 gözlem) temel alınmıştır. İlişkisel veritabanı (`JOIN`) ve limit uyum analizlerini gerçekleştirmek amacıyla ikinci tablo olan `BankaRiskPolitikasi` tablosu, bankacılık kredi tahsis standartları referans alınarak analiz senaryosu kapsamında tarafımca modellenmiştir.
