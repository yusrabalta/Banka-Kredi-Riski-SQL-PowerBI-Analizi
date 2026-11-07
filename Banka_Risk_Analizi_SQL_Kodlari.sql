/* =========================================================================
   PROJE: BANKACILIK KREDİ RİSKİ VE PORTFÖY PERFORMANS ANALİZİ
  
   ========================================================================= */

USE BankaRiskDB;

-- ====================================================================
--VERİYİ TANIMA, TİP DÜZELTME VE HATALI KAYITLARI TEMİZLEME


-- Tablonun ilk 10 satırına bakış ve toplam satır sayısı (32.581)
SELECT TOP 10 * 
FROM KrediBasvurulari;

SELECT COUNT(*) AS Toplam_Basvuru_Sayisi 
FROM KrediBasvurulari;

-- Nokta/Ondalık uyuşmazlığını çözmek için Veri Tipi Dönüşümü (UPDATE ve ALTER TABLE)
UPDATE KrediBasvurulari SET person_emp_length = NULL WHERE person_emp_length = '';
UPDATE KrediBasvurulari SET loan_int_rate = NULL WHERE loan_int_rate = '';
UPDATE KrediBasvurulari SET loan_percent_income = NULL WHERE loan_percent_income = '';

ALTER TABLE KrediBasvurulari ALTER COLUMN person_emp_length FLOAT;
ALTER TABLE KrediBasvurulari ALTER COLUMN loan_int_rate FLOAT;
ALTER TABLE KrediBasvurulari ALTER COLUMN loan_percent_income FLOAT;

--  Yaşı 100'den büyük VEYA çalışma süresi 60 yıldan fazla olan aykırı (outlier) kayıtları bulma
SELECT * 
FROM KrediBasvurulari
WHERE person_age > 100 
   OR person_emp_length > 60;

-- Tespit edilen 7 hatalı kaydı tablodan kalıcı olarak silme
DELETE FROM KrediBasvurulari
WHERE person_age > 100 
   OR person_emp_length > 60;

-- Boş (NULL) Hücre Kontrolü ve kalan temiz kayıt sayısı (32.574)
SELECT 
    COUNT(*) AS Toplam_Temiz_Kayit,
    COUNT(loan_int_rate) AS Faiz_Orani_Dolu_Olanlar,
    COUNT(*) - COUNT(loan_int_rate) AS Faiz_Orani_Bos_Olanlar
FROM KrediBasvurulari;


-- ====================================================================
-- BANKA KREDİ RİSKİ ANALİZİ (GROUP BY & CASE WHEN)

-- Kredi Amacına Göre Risk ve Batık Oranı Analizi
SELECT 
    loan_intent AS Kredi_Amaci,
    COUNT(*) AS Toplam_Basvuru_Sayisi,
    SUM(CAST(loan_status AS INT)) AS Batik_Kredi_Sayisi,
    ROUND(AVG(CAST(loan_status AS FLOAT)) * 100, 2) AS Batik_Orani_Yuzde,
    ROUND(AVG(CAST(loan_amnt AS FLOAT)), 0) AS Ortalama_Kredi_Tutari,
    ROUND(AVG(loan_int_rate), 2) AS Ortalama_Faiz_Orani
FROM KrediBasvurulari
GROUP BY loan_intent
ORDER BY Batik_Orani_Yuzde DESC;

-- CASE WHEN ile Gelir/Kredi Yükü Segmentasyonu (%30 Kırılma Noktası Analizi)
SELECT 
    CASE 
        WHEN loan_percent_income < 0.15 THEN '1 - Düşük Yük (%15 Altı)'
        WHEN loan_percent_income >= 0.15 AND loan_percent_income < 0.30 THEN '2 - Orta Yük (%15 - %30 Arası)'
        WHEN loan_percent_income >= 0.30 AND loan_percent_income < 0.45 THEN '3 - Yüksek Yük (%30 - %45 Arası)'
        ELSE '4 - Kritik Tehlike (%45 ve Üzeri)'
    END AS Gelir_Kredi_Yuku_Grubu,
    COUNT(*) AS Musteri_Sayisi,
    ROUND(AVG(CAST(loan_Income_Orani_Kontrol.person_income AS FLOAT)), 0) AS Ortalama_Yillik_Gelir,
    SUM(CAST(loan_status AS INT)) AS Batik_Musteri_Sayisi,
    ROUND(AVG(CAST(loan_status AS FLOAT)) * 100, 2) AS Batik_Orani_Yuzde
FROM KrediBasvurulari AS loan_Income_Orani_Kontrol
GROUP BY 
    CASE 
        WHEN loan_percent_income < 0.15 THEN '1 - Düşük Yük (%15 Altı)'
        WHEN loan_percent_income >= 0.15 AND loan_percent_income < 0.30 THEN '2 - Orta Yük (%15 - %30 Arası)'
        WHEN loan_percent_income >= 0.30 AND loan_percent_income < 0.45 THEN '3 - Yüksek Yük (%30 - %45 Arası)'
        ELSE '4 - Kritik Tehlike (%45 ve Üzeri)'
    END
ORDER BY Gelir_Kredi_Yuku_Grubu ASC;


-- ====================================================================
-- İKİNCİ TABLO OLUŞTURMA VE INNER JOIN İLE LİMİT ANALİZİ


--  Bankanın Risk Politikası tablosunu oluşturma ve veri ekleme
CREATE TABLE BankaRiskPolitikasi (
    loan_grade NVARCHAR(10) PRIMARY KEY,
    Derece_Aciklamasi NVARCHAR(50),
    Maks_Izin_Verilen_Gelir_Orani FLOAT,
    Zorunlu_Teminat_Durumu NVARCHAR(30)
);

INSERT INTO BankaRiskPolitikasi VALUES
('A', 'A - Çok Düşük Risk (Prime)', 0.35, 'Teminatsız'),
('B', 'B - Düşük Risk (İyi)', 0.30, 'Teminatsız'),
('C', 'C - Orta Risk (Standart)', 0.25, 'Kefil Şartı'),
('D', 'D - Orta-Yüksek Risk (İzleme)', 0.20, 'Kefil Şartı'),
('E', 'E - Yüksek Risk (Spekülatif)', 0.15, 'İpotek/Teminat Şart'),
('F', 'F - Çok Yüksek Risk', 0.10, 'İpotek/Teminat Şart'),
('G', 'G - Kritik Tehlike (Red Önerilir)', 0.05, 'Yönetim Kurulu Onayı');

SELECT * FROM BankaRiskPolitikasi;

--  İki Tabloyu INNER JOIN ile Birleştirip Politika Limit Aşımlarını Yakalama
SELECT 
    P.Derece_Aciklamasi,
    P.Zorunlu_Teminat_Durumu,
    P.Maks_Izin_Verilen_Gelir_Orani AS Politika_Limiti,
    CASE 
        WHEN K.loan_percent_income > P.Maks_Izin_Verilen_Gelir_Orani THEN 'İHLAL (Limit Aşımı Var!)'
        ELSE 'UYGUN (Politika İçi)'
    END AS Denetim_Durumu,
    COUNT(*) AS Kredi_Sayisi,
    SUM(CAST(K.loan_status AS INT)) AS Batik_Kredi_Sayisi,
    ROUND(AVG(CAST(K.loan_status AS FLOAT)) * 100, 2) AS Batik_Orani_Yuzde
FROM KrediBasvurulari AS K
INNER JOIN BankaRiskPolitikasi AS P 
    ON K.loan_grade = P.loan_grade
GROUP BY 
    P.Derece_Aciklamasi,
    P.Zorunlu_Teminat_Durumu,
    P.Maks_Izin_Verilen_Gelir_Orani,
    CASE 
        WHEN K.loan_percent_income > P.Maks_Izin_Verilen_Gelir_Orani THEN 'İHLAL (Limit Aşımı Var!)'
        ELSE 'UYGUN (Politika İçi)'
    END
ORDER BY P.Derece_Aciklamasi ASC, Denetim_Durumu DESC;


-- ====================================================================
-- WITH CTE & OVER PARTITION BY İLE Z-SKORU


-- İstatistiksel Z-Skoru ile Grup İçi Anomali Tespiti (Z > 2.5)
WITH IstatistikTablosu AS (
    SELECT 
        person_age AS Yas,
        person_income AS Yillik_Gelir,
        loan_intent AS Kredi_Amaci,
        loan_grade AS Kredi_Notu,
        loan_amnt AS Cekilen_Kredi,
        loan_status AS Batik_Durumu,
        ROUND(AVG(CAST(loan_amnt AS FLOAT)) OVER (PARTITION BY loan_intent), 0) AS Grup_Ortalama_Kredi,
        ROUND(STDEV(CAST(loan_amnt AS FLOAT)) OVER (PARTITION BY loan_intent), 0) AS Grup_Standart_Sapma,
        ROUND(
            (CAST(loan_amnt AS FLOAT) - AVG(CAST(loan_amnt AS FLOAT)) OVER (PARTITION BY loan_intent)) 
            / STDEV(CAST(loan_amnt AS FLOAT)) OVER (PARTITION BY loan_intent), 
        2) AS Z_Skoru
    FROM KrediBasvurulari
)
SELECT TOP 20 *
FROM IstatistikTablosu
WHERE Z_Skoru > 2.5
ORDER BY Z_Skoru DESC, Yillik_Gelir ASC;


-- ====================================================================
--  POWER BI İÇİN SANAL RAPOR TABLOSU (CREATE VIEW) OLUŞTURMA

GO

CREATE VIEW vw_BankaRiskAnalizi AS
SELECT 
    K.person_age AS Yas,
    CASE 
        WHEN K.person_age < 26 THEN '18-25 (Genç)'
        WHEN K.person_age BETWEEN 26 AND 35 THEN '26-35 (Genç Yetişkin)'
        WHEN K.person_age BETWEEN 36 AND 50 THEN '36-50 (Orta Yaş)'
        ELSE '50+ (Kıdemli)'
    END AS Yas_Grubu,
    K.person_income AS Yillik_Gelir,
    K.person_home_ownership AS Ev_Durumu,
    K.person_emp_length AS Calisma_Yili,
    K.loan_intent AS Kredi_Amaci,
    K.loan_grade AS Kredi_Notu,
    P.Derece_Aciklamasi,
    P.Zorunlu_Teminat_Durumu,
    K.loan_amnt AS Kredi_Tutari,
    K.loan_int_rate AS Faiz_Orani,
    K.loan_status AS Batik_Mi,
    CASE 
        WHEN K.loan_status = 1 THEN 'Batık (Ödenemedi)'
        ELSE 'Normal (Ödeniyor)'
    END AS Kredi_Durum_Metni,
    K.loan_percent_income AS Gelir_Kredi_Orani,
    CASE 
        WHEN K.loan_percent_income < 0.15 THEN '1 - Düşük Yük (<%15)'
        WHEN K.loan_percent_income < 0.30 THEN '2 - Orta Yük (%15-%30)'
        WHEN K.loan_percent_income < 0.45 THEN '3 - Yüksek Yük (%30-%45)'
        ELSE '4 - Kritik Tehlike (>%45)'
    END AS Gelir_Yuku_Grubu,
    P.Maks_Izin_Verilen_Gelir_Orani AS Politika_Limiti,
    CASE 
        WHEN K.loan_percent_income > P.Maks_Izin_Verilen_Gelir_Orani THEN 'İHLAL (Limit Aşımı)'
        ELSE 'UYGUN (Politika İçi)'
    END AS Denetim_Durumu,
    ROUND(
        (CAST(K.loan_amnt AS FLOAT) - AVG(CAST(K.loan_amnt AS FLOAT)) OVER (PARTITION BY K.loan_intent)) 
        / STDEV(CAST(K.loan_amnt AS FLOAT)) OVER (PARTITION BY K.loan_intent), 
    2) AS Kredi_Z_Skoru
FROM KrediBasvurulari AS K
INNER JOIN BankaRiskPolitikasi AS P 
    ON K.loan_grade = P.loan_grade;
GO

-- Oluşturduğumuz View'ı test etme sorgumuz:
SELECT TOP 20 * FROM vw_BankaRiskAnalizi;