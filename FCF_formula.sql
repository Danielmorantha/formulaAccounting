


-- FCF formula dengan EBT gabungan full tahun
WITH revenue AS(
    SELECT SUM(ji.credit) - SUM(ji.debit) AS total_revenue
    FROM journal_items ji
    INNER JOIN chart_of_accounts coa ON ji.account = coa.id
    WHERE coa.type = 4
),
expense AS(
    SELECT SUM(ji.debit) - SUM(ji.credit) AS total_expense
    FROM journal_items ji
    INNER JOIN chart_of_accounts coa ON ji.account = coa.id
    WHERE coa.type = 5
),
Param_FCF AS(
    SELECT  YEAR(ji.created_at) AS Tahun,
            SUM(CASE 
                    WHEN coat.id = 1 
                    THEN ji.debit-ji.credit 
                    ELSE 0 
               END) AS depreciation_amortization,

            (SUM(CASE 
                    WHEN coat.id = 1 AND coat_sub.name = 'Current Asset' 
                    THEN ji.debit - ji.credit 
                    ELSE 0 
                END) - 
            SUM(CASE 
                    WHEN coat.id = 2 AND coat_sub.name = 'Current Liability' 
                    THEN ji.credit - ji.debit 
                    ELSE 0 
                END)
            ) AS change_in_working_capital,
            SUM(CASE 
                    WHEN coat.id = 1 AND coat_sub.name = 'Fixed Asset' 
                    THEN ji.debit - ji.credit 
                    ELSE 0 
                END) AS CapEx
    FROM journal_items ji
    INNER JOIN chart_of_accounts coa ON ji.account = coa.id
    INNER JOIN chart_of_account_types coat ON coa.type = coat.id
    INNER JOIN chart_of_account_sub_types coat_sub ON coat.id = coat_sub.type
    GROUP BY YEAR(ji.created_at)
)
SELECT 
    Param_FCF.Tahun AS Tahun, 
    CONCAT('Rp. ', FORMAT(revenue.total_revenue, 2,'id_ID')) AS total_revenue, 
    CONCAT('Rp. ', FORMAT(expense.total_expense, 2,'id_ID')) AS total_expense, 
    CONCAT
    ('Rp. ', 
        FORMAT
        (
            ( 
                (revenue.total_revenue - expense.total_expense) + 
                Param_FCF.depreciation_amortization +
                Param_FCF.change_in_working_capital -
                Param_FCF.CapEx
            ),2,'id_ID'
        )
    ) AS free_cash_flow
FROM revenue, expense, Param_FCF;


-- FCF formula dengan EBT per tahun

WITH revenue AS (
    SELECT 
        YEAR(ji.created_at) AS Tahun,
        SUM(ji.credit) - SUM(ji.debit) AS total_revenue
    FROM journal_items ji
    INNER JOIN chart_of_accounts coa ON ji.account = coa.id
    WHERE coa.type = 4
    GROUP BY YEAR(ji.created_at)
),
expense AS (
    SELECT 
        YEAR(ji.created_at) AS Tahun,
        SUM(ji.debit) - SUM(ji.credit) AS total_expense
    FROM journal_items ji
    INNER JOIN chart_of_accounts coa ON ji.account = coa.id
    WHERE coa.type = 5
    GROUP BY YEAR(ji.created_at)
),
Param_FCF AS (
    SELECT  
        YEAR(ji.created_at) AS Tahun,
        SUM(CASE 
                WHEN coat.id = 1 
                THEN ji.debit - ji.credit 
                ELSE 0 
            END) AS depreciation_amortization,
        (SUM(CASE 
                WHEN coat.id = 1 AND coat_sub.name = 'Current Asset' 
                THEN ji.debit - ji.credit 
                ELSE 0 
            END) - 
        SUM(CASE 
                WHEN coat.id = 2 AND coat_sub.name = 'Current Liability' 
                THEN ji.credit - ji.debit 
                ELSE 0 
            END)
        ) AS change_in_working_capital,
        SUM(CASE 
                WHEN coat.id = 1 AND coat_sub.name = 'Fixed Asset' 
                THEN ji.debit - ji.credit 
                ELSE 0 
            END) AS CapEx
    FROM journal_items ji
    INNER JOIN chart_of_accounts coa ON ji.account = coa.id
    INNER JOIN chart_of_account_types coat ON coa.type = coat.id
    INNER JOIN chart_of_account_sub_types coat_sub ON coat.id = coat_sub.type
    GROUP BY YEAR(ji.created_at)
)
SELECT 
    Param_FCF.Tahun AS Tahun, 
    CONCAT('Rp. ', FORMAT(revenue.total_revenue, 2, 'id_ID')) AS total_revenue, 
    CONCAT('Rp. ', FORMAT(expense.total_expense, 2, 'id_ID')) AS total_expense, 
    FORMAT((revenue.total_revenue - expense.total_expense), 2, 'id_ID') AS EBT,
    CONCAT(
        'Rp. ', 
        FORMAT(
            (
                (revenue.total_revenue - expense.total_expense) + 
                Param_FCF.depreciation_amortization + 
                Param_FCF.change_in_working_capital - 
                Param_FCF.CapEx
            ), 2, 'id_ID'
        )
    ) AS free_cash_flow
FROM Param_FCF
JOIN revenue ON Param_FCF.Tahun = revenue.Tahun
JOIN expense ON Param_FCF.Tahun = expense.Tahun;


-----------------------------------------------------------------------------------



-- Menghitung Cost of Debt (Kd)
-- Rumus dari KD = TIE/TD (Total Interest Expense / Total Debt)
-- Kd = 9,40
-- Total hutang pertahun
-- SELECT YEAR(ac_id.date) AS Tahun, coa.name AS nama_pembayaran, SUM(ac_id.amount) AS total_Hutang 
-- FROM invoice_payments ac_id 
-- INNER JOIN chart_of_accounts coa ON ac_id.account_id = coa.id
-- WHERE coa.id = 145
-- GROUP BY YEAR(date); 

WITH hutangPertahun AS(
    SELECT YEAR(ac_id.date) AS Tahun, coa.name AS nama_pembayaran, FORMAT(SUM(ac_id.amount), 2,'id_ID') AS total_Hutang_per_share 
    FROM invoice_payments ac_id 
    INNER JOIN chart_of_accounts coa ON ac_id.account_id = coa.id
    WHERE coa.name LIKE '%Hutang%'
    GROUP BY YEAR(date)
),
bebanBunga AS(
    SELECT YEAR(je.date) AS Tahun, FORMAT(SUM(ji.debit), 2,'id_ID') AS total_beban_bunga_per_share 
    FROM journal_items ji 
    INNER JOIN journal_entries je ON  ji.journal = je.id
    WHERE ji.description LIKE '%Pajak Bunga%' GROUP BY YEAR(je.date)
),
Cost_ofDebt AS(
    SELECT TD.Tahun AS Tahun_hutang, 
    TIE.Tahun AS Tahun_beban_bunga, 
    TD.total_Hutang_per_share AS total_hutang_per_share, 
    TIE.total_beban_bunga_per_share AS total_beban_bunga_per_share,
    FORMAT((TIE.total_beban_bunga_per_share / TD.total_Hutang_per_share), 2,'id_ID') AS Cost_ofDebt
    FROM hutangPertahun TD, bebanBunga TIE
    GROUP BY YEAR(TIE.date)
) SELECT * FROM Cost_ofDebt;


-- Total beban hutang pertahun
WITH hutangPertahun AS(
    SELECT YEAR(ac_id.date) AS Tahun, coa.name AS nama_pembayaran, FORMAT(SUM(ac_id.amount), 2,'id_ID') AS total_Hutang 
    FROM invoice_payments ac_id 
    INNER JOIN chart_of_accounts coa ON ac_id.account_id = coa.id
    WHERE coa.name LIKE '%Hutang%'
    GROUP BY YEAR(date)
),
bebanBunga AS(
    SELECT YEAR(je.date) AS Tahun, FORMAT(SUM(ji.debit), 2,'id_ID') AS total_beban_bunga 
    FROM journal_items ji 
    INNER JOIN journal_entries je ON  ji.journal = je.id
    WHERE ji.description LIKE '%Pajak Bunga%' GROUP BY YEAR(je.date)
)SELECT * FROM hutangPertahun, bebanBunga;


-- Total Ekuitas = Total Aset − Total Hutang

-------------------------------------------------------------------------------
WITH ekuitas AS(
    SELECT YEAR(ji.created_at) AS Tahun_ekuitas, FORMAT(SUM(credit)-SUM(debit), 2, 'id_ID') AS total_ekuitas
    FROM journal_items ji 
    INNER JOIN chart_of_accounts coa ON ji.account = coa.id
    INNER JOIN chart_of_account_types coa_type ON coa.type = coa_type.id
    INNER JOIN chart_of_account_sub_types coat_sub ON coa_type.id = coat_sub.type
    WHERE coat_sub.name = 'Equity' AND coa_type.id = 3
    GROUP BY YEAR(ji.created_at)
)SELECT * FROM ekuitas;





-- Proporsi Ekuitas (E/V) dan Utang (D/V)
-- Rumus Proporsi Ekuitas : E/V = Total Equity(E) / Total Value of the Firm(V)
-- Rumus Proporsi Utang   : D/V = Total Debt(D) / Total Value of the Firm(V)
-- Rumus Total Value of the Firm : V = Total Equity + Total Debt
------Hasil Query tgl 11/7/2024------------
-- Tahun =  2023
-- Total_EV = 1,25
-- Total_DV = -0,25
-- Total_value = -5353433651.85
-------------------------------------------

--------------------------------------------------------------------------------
-- WITH E AS(
--     SELECT YEAR(ji.created_at) AS Tahun_ekuitas, (SUM(credit)-SUM(debit)) AS total_ekuitas
--     FROM journal_items ji 
--     INNER JOIN chart_of_accounts coa ON ji.account = coa.id
--     INNER JOIN chart_of_account_types coa_type ON coa.type = coa_type.id
--     INNER JOIN chart_of_account_sub_types coat_sub ON coa_type.id = coat_sub.type
--     WHERE coat_sub.name = 'Equity' AND coa_type.id = 3
--     GROUP BY YEAR(ji.created_at)
-- ),
-- D AS(
--     SELECT YEAR(coa.created_at) AS Tahun_Hutang, coa.name AS nama_pembayaran, SUM(ac_id.amount) AS total_Hutang 
--     FROM invoice_payments ac_id 
--     INNER JOIN chart_of_accounts coa ON ac_id.account_id = coa.id
--     WHERE coa.name LIKE '%Hutang%'
--     GROUP BY YEAR(coa.created_at)
-- ),
-- V AS(
--     SELECT E.Tahun_ekuitas AS Tahun_Value, (E.total_ekuitas + D.total_Hutang) AS Total_Value 
--     FROM E 
--     INNER JOIN D ON E.Tahun_ekuitas = D.Tahun_Hutang
-- ),
-- Total_EV AS(
--     SELECT V.Tahun_Value AS Tahun_EV, FORMAT((E.total_ekuitas / V.Total_Value), 2, 'id_ID') AS total_EV
--     FROM V INNER JOIN E ON V.Tahun_Value = E.Tahun_ekuitas
-- ),
-- Total_DV AS(
--     SELECT V.Tahun_Value AS Tahun_DV, FORMAT((D.total_Hutang / V.Total_Value), 2, 'id_ID') AS total_DV
--     FROM V INNER JOIN D ON V.Tahun_Value = D.Tahun_Hutang
-- )
-- SELECT Total_DV.Tahun_DV AS Tahun, 
-- Total_EV.total_EV AS Total_EV, 
-- Total_DV.total_DV AS Total_DV,
-- V.Total_Value AS Total_value
-- FROM V 
-- INNER JOIN Total_EV ON V.Tahun_Value = Total_EV.Tahun_EV
-- INNER JOIN Total_DV ON V.Tahun_Value = Total_DV.Tahun_DV;


WITH E AS(
    SELECT YEAR(ji.created_at) AS Tahun_ekuitas, (SUM(credit)-SUM(debit)) AS total_ekuitas
    FROM journal_items ji 
    INNER JOIN chart_of_accounts coa ON ji.account = coa.id
    INNER JOIN chart_of_account_types coa_type ON coa.type = coa_type.id
    INNER JOIN chart_of_account_sub_types coat_sub ON coa_type.id = coat_sub.type
    WHERE coat_sub.name = 'Equity' AND coa_type.id = 3
    GROUP BY YEAR(ji.created_at)
),
D AS(
    SELECT YEAR(coa.created_at) AS Tahun_Hutang, coa.name AS nama_pembayaran, SUM(ac_id.amount) AS total_Hutang 
    FROM invoice_payments ac_id 
    INNER JOIN chart_of_accounts coa ON ac_id.account_id = coa.id
    WHERE coa.name LIKE '%Hutang%'
    GROUP BY YEAR(coa.created_at)
),
V AS(
    SELECT E.Tahun_ekuitas AS Tahun_Value, (E.total_ekuitas + D.total_Hutang) AS Total_Value 
    FROM E 
    INNER JOIN D ON E.Tahun_ekuitas = D.Tahun_Hutang
),
Total_EV AS(
    SELECT V.Tahun_Value AS Tahun_EV, FORMAT((E.total_ekuitas / V.Total_Value), 2, 'id_ID') AS total_EV
    FROM V INNER JOIN E ON V.Tahun_Value = E.Tahun_ekuitas
),
Total_DV AS(
    SELECT V.Tahun_Value AS Tahun_DV, FORMAT((D.total_Hutang / V.Total_Value), 2, 'id_ID') AS total_DV
    FROM V INNER JOIN D ON V.Tahun_Value = D.Tahun_Hutang
)
SELECT Total_DV.Tahun_DV AS Tahun, 
Total_EV.total_EV AS Total_EV, 
Total_DV.total_DV AS Total_DV,
V.Total_Value AS Total_value
FROM V 
INNER JOIN Total_EV ON V.Tahun_Value = Total_EV.Tahun_EV
INNER JOIN Total_DV ON V.Tahun_Value = Total_DV.Tahun_DV;
-------------------------------------------------------------------------------









-- update tanggal 11/7/2024
-- Tax Rate
-- Rumus Tax rate: T = Total Tax Expanse / Earnings Before Tax
--Tax rate  = 44.653.208.899,45 pada tahun 2023
-- Tax rate = 517.646.163.826,11 pada tahun 2024

WITH revenue AS(
    SELECT YEAR(ji.created_at) AS Tahun_Pendapatan,
    SUM(ji.credit) - SUM(ji.debit) AS total_revenue
    FROM journal_items ji
    INNER JOIN chart_of_accounts coa ON ji.account = coa.id
    WHERE coa.type = 4
    GROUP BY YEAR(ji.created_at)
),
bebanPajak AS(
    SELECT YEAR(ji.created_at) AS Tahun_bebanPajak,
    SUM(ji.debit) - SUM(ji.credit) AS total_expense
    FROM journal_items ji
    INNER JOIN chart_of_accounts coa ON ji.account = coa.id
    WHERE coa.type = 5
    GROUP BY YEAR(JI.created_at)
),
EBT AS(
    SELECT revenue.Tahun_Pendapatan as Tahun_Pendapatan,
    (revenue.total_revenue - bebanPajak.total_expense) as total_EBT
    FROM revenue
    INNER JOIN bebanPajak ON revenue.Tahun_Pendapatan = bebanPajak.Tahun_bebanPajak
)
SELECT EBT.Tahun_Pendapatan AS Tahun_EBT,
FORMAT((bebanPajak.total_expense - EBT.total_EBT), 2, 'id_ID') AS TaxRate
FROM bebanPajak
INNER JOIN EBT ON bebanPajak.Tahun_bebanPajak = EBT.Tahun_Pendapatan
WHERE ebt.total_EBT != 0


-------------------------------------------------------------------









--- query di jalankan tgl 12/7/2024
--- Hitung WWAC
-- WACC = ( (E/V) x ke ) + ( (D/V) x Kd x (1-T) ) = 3.938725
-- Ket: 
-- E = Total Ekuitas
-- D = Total Hutang
-- V =  Total Nilai Perusahaan ( E + D)
-- Ke = Cost of Equity = 3.938725
-- Kd = Cost of Debt
-- T = Tax Rate
-----------------------------------------------------------------------------
WITH E AS(
    SELECT YEAR(ji.created_at) AS Tahun_ekuitas, (SUM(credit)-SUM(debit)) AS total_ekuitas
    FROM journal_items ji 
    INNER JOIN chart_of_accounts coa ON ji.account = coa.id
    INNER JOIN chart_of_account_types coa_type ON coa.type = coa_type.id
    INNER JOIN chart_of_account_sub_types coat_sub ON coa_type.id = coat_sub.type
    WHERE coat_sub.name = 'Equity' AND coa_type.id = 3
    GROUP BY YEAR(ji.created_at)
),
D AS(
    SELECT YEAR(coa.created_at) AS Tahun_Hutang, coa.name AS nama_pembayaran, SUM(ac_id.amount) AS total_Hutang 
    FROM invoice_payments ac_id 
    INNER JOIN chart_of_accounts coa ON ac_id.account_id = coa.id
    WHERE coa.name LIKE '%Hutang%'
    GROUP BY YEAR(coa.created_at)
),
V AS(
    SELECT E.Tahun_ekuitas AS Tahun_Value, (E.total_ekuitas + D.total_Hutang) AS Total_Value 
    FROM E 
    INNER JOIN D ON E.Tahun_ekuitas = D.Tahun_Hutang
),
Total_EV AS(
    SELECT V.Tahun_Value AS Tahun_EV, FORMAT((E.total_ekuitas / V.Total_Value), 2, 'id_ID') AS total_EV
    FROM V INNER JOIN E ON V.Tahun_Value = E.Tahun_ekuitas
),
Total_DV AS(
    SELECT V.Tahun_Value AS Tahun_DV, FORMAT((D.total_Hutang / V.Total_Value), 2, 'id_ID') AS total_DV
    FROM V INNER JOIN D ON V.Tahun_Value = D.Tahun_Hutang
),
hutangPertahun AS(
    SELECT YEAR(ac_id.date) AS Tahun, coa.name AS nama_pembayaran, FORMAT(SUM(ac_id.amount), 2,'id_ID') AS total_Hutang_per_share 
    FROM invoice_payments ac_id 
    INNER JOIN chart_of_accounts coa ON ac_id.account_id = coa.id
    WHERE coa.name LIKE '%Hutang%'
    GROUP BY YEAR(date)
),
bebanBunga AS(
    SELECT YEAR(je.date) AS Tahun, FORMAT(SUM(ji.debit), 2,'id_ID') AS total_beban_bunga_per_share 
    FROM journal_items ji 
    INNER JOIN journal_entries je ON  ji.journal = je.id
    WHERE ji.description LIKE '%Pajak Bunga%' GROUP BY YEAR(je.date)
),
Cost_ofDebt AS(
    SELECT TD.Tahun AS Tahun_hutang, 
    TIE.Tahun AS Tahun_beban_bunga, 
    TD.total_Hutang_per_share AS total_hutang_per_share, 
    TIE.total_beban_bunga_per_share AS total_beban_bunga_per_share,
    FORMAT((TIE.total_beban_bunga_per_share / TD.total_Hutang_per_share), 2,'id_ID') AS Cost_ofDebt
    FROM hutangPertahun TD, bebanBunga TIE
    GROUP BY YEAR(TIE.Tahun)
),
revenue AS(
    SELECT YEAR(ji.created_at) AS Tahun_Pendapatan,
    SUM(ji.credit) - SUM(ji.debit) AS total_revenue
    FROM journal_items ji
    INNER JOIN chart_of_accounts coa ON ji.account = coa.id
    WHERE coa.type = 4
    GROUP BY YEAR(ji.created_at)
),
bebanPajak AS(
    SELECT YEAR(ji.created_at) AS Tahun_bebanPajak,
    SUM(ji.debit) - SUM(ji.credit) AS total_expense
    FROM journal_items ji
    INNER JOIN chart_of_accounts coa ON ji.account = coa.id
    WHERE coa.type = 5
    GROUP BY YEAR(JI.created_at)
),
EBT AS(
    SELECT revenue.Tahun_Pendapatan as Tahun_Pendapatan,
    (revenue.total_revenue - bebanPajak.total_expense) as total_EBT
    FROM revenue
    INNER JOIN bebanPajak ON revenue.Tahun_Pendapatan = bebanPajak.Tahun_bebanPajak
),
Tax AS(
    SELECT EBT.Tahun_Pendapatan AS Tahun_EBT,
    FORMAT((bebanPajak.total_expense - EBT.total_EBT), 2, 'id_ID') AS TaxRate
    FROM bebanPajak
    INNER JOIN EBT ON bebanPajak.Tahun_bebanPajak = EBT.Tahun_Pendapatan
    WHERE ebt.total_EBT != 0
),
WWAC AS(
    SELECT Tax.Tahun_EBT AS Tahun_WWAC, ( (Total_EV.total_EV * 3.938725) + (Total_DV.total_DV * Cost_ofDebt.Cost_ofDebt) * (1-Tax.TaxRate) ) AS WWAC
    FROM Total_EV 
    INNER JOIN Total_DV ON Total_EV.Tahun_EV = Total_DV.Tahun_DV
    INNER JOIN Cost_ofDebt ON Total_DV.Tahun_DV = Cost_ofDebt.Tahun_hutang
    INNER JOIN Tax ON Cost_ofDebt.Tahun_hutang = Tax.Tahun_EBT
)SELECT * FROM WWAC;





-- Terminal Values(TV)
-- TV = ( FCFx(1+g) ) / r-g
-- ket:
-- FCF = Free Cash Flow (arus kas bebas pada akhir periode proyeksi)
-- g = tingkat pertumbuhan tetap
-- r = discount rate (tingkat diskonto)
-- g = ( Nilai Akhir(Pendapatan) - Nilai Awal(Pendapatan) ) / Nilai Awal Group By Year()
-- g = AVG(g)


WITH revenue_per_tahun AS(
    SELECT 
        YEAR(ji.created_at) AS Tahun,
        SUM(ji.debit) AS total_revenue
    FROM journal_items ji
    INNER JOIN chart_of_accounts coa ON ji.account = coa.id
    WHERE coa.type = 4
    GROUP BY YEAR(ji.created_at) 
),
growth_rate AS (
SELECT 
r1.Tahun AS Tahun,
r1.total_revenue,
r2.total_revenue AS previous_revenue,
((r1.total_revenue - r2.total_revenue) / r2.total_revenue) AS revenue_growth_rate
FROM revenue_per_tahun r1
LEFT JOIN revenue_per_tahun r2 ON r1.Tahun = r2.Tahun + 1
)
SELECT growth_rates.Tahun AS tahun, 
revenue_per_tahun.total_revenue AS revenue, 
FORMAT(AVG(growth_rates.revenue_growth_rate), 2, 'id_ID') AS g
FROM revenue_per_tahun 
LEFT JOIN growth_rates ON growth_rates.Tahun = revenue_per_tahun.Tahun;



WITH revenue_per_tahun AS(
    SELECT 
        YEAR(ji.created_at) AS Tahun,
        SUM(ji.debit) AS total_revenue
    FROM journal_items ji
    INNER JOIN chart_of_accounts coa ON ji.account = coa.id
    WHERE coa.type = 4
    GROUP BY YEAR(ji.created_at) 
),
growth_rate AS (
    SELECT 
        awal.Tahun AS Tahun,
        awal.total_revenue,
        akhir.total_revenue AS previous_revenue,
        ((awal.total_revenue - akhir.total_revenue) / akhir.total_revenue) AS growth_rate_per_tahun
    FROM revenue_per_tahun awal
    LEFT JOIN revenue_per_tahun akhir ON awal.Tahun = akhir.Tahun + 1
),
g AS (
SELECT growth_rates.Tahun AS tahun, 
    revenue_per_tahun.total_revenue AS revenue, 
    AVG(growth_rates.growth_rate_per_tahun) AS growth_rate
FROM revenue_per_tahun 
INNER JOIN growth_rates ON growth_rates.Tahun = revenue_per_tahun.Tahun
) SELECT * FROM g;




-- Nilai G

-- WITH revenue AS(
--     SELECT 
--         YEAR(ji.created_at) AS Tahun,
--         SUM(ji.credit) - SUM(ji.debit) AS total_revenue
--     FROM journal_items ji
--     INNER JOIN chart_of_accounts coa ON ji.account = coa.id
--     WHERE coa.type = 4
--     GROUP BY YEAR(ji.created_at) 
-- )SELECT 


WITH E AS(
    SELECT YEAR(ji.created_at) AS Tahun_ekuitas, (SUM(credit)-SUM(debit)) AS total_ekuitas
    FROM journal_items ji 
    INNER JOIN chart_of_accounts coa ON ji.account = coa.id
    INNER JOIN chart_of_account_types coa_type ON coa.type = coa_type.id
    INNER JOIN chart_of_account_sub_types coat_sub ON coa_type.id = coat_sub.type
    WHERE coat_sub.name = 'Equity' AND coa_type.id = 3
    GROUP BY YEAR(ji.created_at)
),
D AS(
    SELECT YEAR(coa.created_at) AS Tahun_Hutang, coa.name AS nama_pembayaran, SUM(ac_id.amount) AS total_Hutang 
    FROM invoice_payments ac_id 
    INNER JOIN chart_of_accounts coa ON ac_id.account_id = coa.id
    WHERE coa.name LIKE '%Hutang%'
    GROUP BY YEAR(coa.created_at)
),
V AS(
    SELECT E.Tahun_ekuitas AS Tahun_Value, (E.total_ekuitas + D.total_Hutang) AS Total_Value 
    FROM E 
    INNER JOIN D ON E.Tahun_ekuitas = D.Tahun_Hutang
),
Total_EV AS(
    SELECT V.Tahun_Value AS Tahun_EV, FORMAT((E.total_ekuitas / V.Total_Value), 2, 'id_ID') AS total_EV
    FROM V INNER JOIN E ON V.Tahun_Value = E.Tahun_ekuitas
),
Total_DV AS(
    SELECT V.Tahun_Value AS Tahun_DV, FORMAT((D.total_Hutang / V.Total_Value), 2, 'id_ID') AS total_DV
    FROM V INNER JOIN D ON V.Tahun_Value = D.Tahun_Hutang
),
hutangPertahun AS(
    SELECT YEAR(ac_id.date) AS Tahun, coa.name AS nama_pembayaran, FORMAT(SUM(ac_id.amount), 2,'id_ID') AS total_Hutang_per_share 
    FROM invoice_payments ac_id 
    INNER JOIN chart_of_accounts coa ON ac_id.account_id = coa.id
    WHERE coa.name LIKE '%Hutang%'
    GROUP BY YEAR(date)
),
bebanBunga AS(
    SELECT YEAR(je.date) AS Tahun, FORMAT(SUM(ji.debit), 2,'id_ID') AS total_beban_bunga_per_share 
    FROM journal_items ji 
    INNER JOIN journal_entries je ON  ji.journal = je.id
    WHERE ji.description LIKE '%Pajak Bunga%' GROUP BY YEAR(je.date)
),
Cost_ofDebt AS(
    SELECT TD.Tahun AS Tahun_hutang, 
    TIE.Tahun AS Tahun_beban_bunga, 
    TD.total_Hutang_per_share AS total_hutang_per_share, 
    TIE.total_beban_bunga_per_share AS total_beban_bunga_per_share,
    FORMAT((TIE.total_beban_bunga_per_share / TD.total_Hutang_per_share), 2,'id_ID') AS Cost_ofDebt
    FROM hutangPertahun TD, bebanBunga TIE
    GROUP BY YEAR(TIE.Tahun)
),
revenue AS (
    SELECT 
        YEAR(ji.created_at) AS Tahun,
        SUM(ji.credit) - SUM(ji.debit) AS total_revenue
    FROM journal_items ji
    INNER JOIN chart_of_accounts coa ON ji.account = coa.id
    WHERE coa.type = 4
    GROUP BY YEAR(ji.created_at)
),
bebanPajak AS(
    SELECT YEAR(ji.created_at) AS Tahun_bebanPajak,
    SUM(ji.debit) - SUM(ji.credit) AS total_expense
    FROM journal_items ji
    INNER JOIN chart_of_accounts coa ON ji.account = coa.id
    WHERE coa.type = 5
    GROUP BY YEAR(JI.created_at)
),
EBT AS(
    SELECT revenue.Tahun as Tahun_Pendapatan,
    (revenue.total_revenue - bebanPajak.total_expense) as total_EBT
    FROM revenue
    INNER JOIN bebanPajak ON revenue.Tahun = bebanPajak.Tahun_bebanPajak
),
Tax AS(
    SELECT EBT.Tahun_Pendapatan AS Tahun_EBT,
    FORMAT((bebanPajak.total_expense - EBT.total_EBT), 2, 'id_ID') AS TaxRate
    FROM bebanPajak
    INNER JOIN EBT ON bebanPajak.Tahun_bebanPajak = EBT.Tahun_Pendapatan
    WHERE ebt.total_EBT != 0
),
WWAC AS(
    SELECT Tax.Tahun_EBT AS Tahun_WWAC, ( (Total_EV.total_EV * 3.938725) + (Total_DV.total_DV * Cost_ofDebt.Cost_ofDebt) * (1-Tax.TaxRate) ) AS WWAC
    FROM Total_EV 
    INNER JOIN Total_DV ON Total_EV.Tahun_EV = Total_DV.Tahun_DV
    INNER JOIN Cost_ofDebt ON Total_DV.Tahun_DV = Cost_ofDebt.Tahun_hutang
    INNER JOIN Tax ON Cost_ofDebt.Tahun_hutang = Tax.Tahun_EBT
),
expense AS (
    SELECT 
        YEAR(ji.created_at) AS Tahun,
        SUM(ji.debit) - SUM(ji.credit) AS total_expense
    FROM journal_items ji
    INNER JOIN chart_of_accounts coa ON ji.account = coa.id
    WHERE coa.type = 5
    GROUP BY YEAR(ji.created_at)
),
growth_rate AS (
    SELECT 
        r1.Tahun AS Tahun,
        r1.total_revenue,
        r2.total_revenue AS revenue_sebelum,
        ((r1.total_revenue - r2.total_revenue) / r2.total_revenue) AS nilai_G
    FROM revenue r1
    LEFT JOIN revenue r2 ON r1.Tahun = r2.Tahun + 1
),
rerata_g AS(
SELECT 
    growth_rate.Tahun AS tahun, 
    FORMAT(revenue.total_revenue, 2, 'id_ID') AS total_revenue,
    CONVERT(AVG(growth_rate.nilai_G), DECIMAL(3,1)) AS rerata_presentase_g
FROM growth_rate INNER JOIN revenue ON growth_rate.Tahun = revenue.Tahun
),
Param_FCF AS (
    SELECT  
        YEAR(ji.created_at) AS Tahun,
        SUM(CASE 
                WHEN coat.id = 1 
                THEN ji.debit - ji.credit 
                ELSE 0 
            END) AS depreciation_amortization,
        (SUM(CASE 
                WHEN coat.id = 1 AND coat_sub.name = 'Current Asset' 
                THEN ji.debit - ji.credit 
                ELSE 0 
            END) - 
        SUM(CASE 
                WHEN coat.id = 2 AND coat_sub.name = 'Current Liability' 
                THEN ji.credit - ji.debit 
                ELSE 0 
            END)
        ) AS change_in_working_capital,
        SUM(CASE 
                WHEN coat.id = 1 AND coat_sub.name = 'Fixed Asset' 
                THEN ji.debit - ji.credit 
                ELSE 0 
            END) AS CapEx
    FROM journal_items ji
    INNER JOIN chart_of_accounts coa ON ji.account = coa.id
    INNER JOIN chart_of_account_types coat ON coa.type = coat.id
    INNER JOIN chart_of_account_sub_types coat_sub ON coat.id = coat_sub.type
    GROUP BY YEAR(ji.created_at)
),
FCF AS(
SELECT 
    Param_FCF.Tahun AS Tahun, 
    FORMAT(revenue.total_revenue, 2, 'id_ID') AS total_revenue, 
    FORMAT(expense.total_expense, 2, 'id_ID') AS total_expense, 
    FORMAT((revenue.total_revenue - expense.total_expense), 2, 'id_ID') AS EBT,
    FORMAT(
            (
                (revenue.total_revenue - expense.total_expense) + 
                Param_FCF.depreciation_amortization + 
                Param_FCF.change_in_working_capital - 
                Param_FCF.CapEx
            ), 2, 'id_ID'
        )AS free_cash_flow
FROM Param_FCF 
LEFT JOIN revenue ON Param_FCF.Tahun = revenue.Tahun
LEFT JOIN expense ON Param_FCF.Tahun = expense.Tahun
LEFT JOIN growth_rate ON Param_FCF.Tahun = growth_rate.Tahun
),
FCF_predik AS(
    SELECT FCF.Tahun AS tahun_predik, FCF.free_cash_flow AS FCF_Akhir 
    FROM FCF
    WHERE FCF.Tahun = (SELECT MAX(FCF.Tahun) FROM FCF)
    UNION ALL
    -- PV OF FCF proyeksi. Rumus : FCF/(1+WWAC)t+1
    -- ket: t+1 = tahun depan,  WWAC = diskon rate(r), melanjutkan PV of Tahun Depan
    SELECT FCF.Tahun + 1, FCF.free_cash_flow * (1 + rerata_g.rerata_presentase_g) AS FCF_proyeksi
    FROM FCF LEFT JOIN rerata_g ON FCF.Tahun = rerata_g.rerata_presentase_g
    WHERE FCF.Tahun < 2028
)
SELECT Param_FCF.Tahun AS tahun,  
FCF.total_revenue AS revenue, 
FCF.total_expense AS total_expense, 
FCF.EBT AS EBT, 
FCF.free_cash_flow AS FCF, rerata_g.rerata_presentase_g AS rerata_g_annual,
FCF_predik.FCF_Akhir / POWER(1 + rerata_g.rerata_presentase_g, FCF_predik.tahun_predik - 2023) AS present_value_fcf,
    -- Calculate Terminal Value using Gordon Growth Model for the last projected year (2028)
(FCF_predik.FCF_proyeksi * (1 + rerata_g.rerata_presentase_g)) / (WWAC.WWAC - rerata_g.rerata_presentase_g) AS terminal_value,
    -- Calculate Present Value of Terminal Value
((FCF_predik.FCF_proyeksi * (1 + rerata_g.rerata_presentase_g)) / (WWAC.WWAC - rerata_g.rerata_presentase_g)) / POWER(1 + WWAC.WWAC, FCF_predik.tahun_predik - 2023) AS present_value_terminal_value
FROM FCF 
LEFT JOIN rerata_g ON FCF.Tahun = rerata_g.tahun
INNER JOIN Param_FCF ON FCF.Tahun = Param_FCF.Tahun
LEFT JOIN FCF_predik ON Param_FCF.Tahun = FCF.tahun_predik
LEFT JOIN WWAC ON FCF.Tahun = WWAC.Tahun_WWAC;







-- revisi dari line 530 - 717 buat hitung fair value
-- rumus fair value 
-- fair value = PV of FCF date('Y', strtotime('+1 year')) + PV of FCF date('Y', strtotime('+2 year')) + PV of FCF date('Y', strtotime('+3 year')) +  PV of Terminal Value
WITH E AS(
    SELECT YEAR(ji.created_at) AS Tahun_ekuitas, (SUM(credit)-SUM(debit)) AS total_ekuitas
    FROM journal_items ji 
    INNER JOIN chart_of_accounts coa ON ji.account = coa.id
    INNER JOIN chart_of_account_types coa_type ON coa.type = coa_type.id
    INNER JOIN chart_of_account_sub_types coat_sub ON coa_type.id = coat_sub.type
    WHERE coat_sub.name = 'Equity' AND coa_type.id = 3
    GROUP BY YEAR(ji.created_at)
),
D AS(
    SELECT YEAR(coa.created_at) AS Tahun_Hutang, coa.name AS nama_pembayaran, SUM(ac_id.amount) AS total_Hutang 
    FROM invoice_payments ac_id 
    INNER JOIN chart_of_accounts coa ON ac_id.account_id = coa.id
    WHERE coa.name LIKE '%Hutang%'
    GROUP BY YEAR(coa.created_at)
),
V AS(
    SELECT E.Tahun_ekuitas AS Tahun_Value, (E.total_ekuitas + D.total_Hutang) AS Total_Value 
    FROM E 
    INNER JOIN D ON E.Tahun_ekuitas = D.Tahun_Hutang
),
Total_EV AS(
    SELECT V.Tahun_Value AS Tahun_EV, FORMAT((E.total_ekuitas / V.Total_Value), 2, 'id_ID') AS total_EV
    FROM V 
    INNER JOIN E ON V.Tahun_Value = E.Tahun_ekuitas
),
Total_DV AS(
    SELECT V.Tahun_Value AS Tahun_DV, FORMAT((D.total_Hutang / V.Total_Value), 2, 'id_ID') AS total_DV
    FROM V 
    INNER JOIN D ON V.Tahun_Value = D.Tahun_Hutang
),
hutangPertahun AS(
    SELECT YEAR(ac_id.date) AS Tahun, coa.name AS nama_pembayaran, FORMAT(SUM(ac_id.amount), 2,'id_ID') AS total_Hutang_per_share 
    FROM invoice_payments ac_id 
    INNER JOIN chart_of_accounts coa ON ac_id.account_id = coa.id
    WHERE coa.name LIKE '%Hutang%'
    GROUP BY YEAR(date)
),
bebanBunga AS(
    SELECT YEAR(je.date) AS Tahun, FORMAT(SUM(ji.debit), 2,'id_ID') AS total_beban_bunga_per_share 
    FROM journal_items ji 
    INNER JOIN journal_entries je ON ji.journal = je.id
    WHERE ji.description LIKE '%Pajak Bunga%' 
    GROUP BY YEAR(je.date)
),
Cost_ofDebt AS(
    SELECT TD.Tahun AS Tahun_hutang, 
           TIE.Tahun AS Tahun_beban_bunga, 
           TD.total_Hutang_per_share AS total_hutang_per_share, 
           TIE.total_beban_bunga_per_share AS total_beban_bunga_per_share,
           FORMAT((TIE.total_beban_bunga_per_share / TD.total_hutang_per_share), 2,'id_ID') AS Cost_ofDebt
    FROM hutangPertahun TD
    INNER JOIN bebanBunga TIE ON TD.Tahun = TIE.Tahun
),
revenue AS (
    SELECT 
        YEAR(ji.created_at) AS Tahun,
        SUM(ji.credit) - SUM(ji.debit) AS total_revenue
    FROM journal_items ji
    INNER JOIN chart_of_accounts coa ON ji.account = coa.id
    WHERE coa.type = 4
    GROUP BY YEAR(ji.created_at)
),
bebanPajak AS(
    SELECT YEAR(ji.created_at) AS Tahun_bebanPajak,
           SUM(ji.debit) - SUM(ji.credit) AS total_expense
    FROM journal_items ji
    INNER JOIN chart_of_accounts coa ON ji.account = coa.id
    WHERE coa.type = 5
    GROUP BY YEAR(ji.created_at)
),
EBT AS(
    SELECT revenue.Tahun AS Tahun_Pendapatan,
           (revenue.total_revenue - bebanPajak.total_expense) AS total_EBT
    FROM revenue
    INNER JOIN bebanPajak ON revenue.Tahun = bebanPajak.Tahun_bebanPajak
),
Tax AS(
    SELECT EBT.Tahun_Pendapatan AS Tahun_EBT,
           FORMAT((bebanPajak.total_expense - EBT.total_EBT), 2, 'id_ID') AS TaxRate
    FROM bebanPajak
    INNER JOIN EBT ON bebanPajak.Tahun_bebanPajak = EBT.Tahun_Pendapatan
    WHERE EBT.total_EBT != 0
),
WWAC AS(
    SELECT Tax.Tahun_EBT AS Tahun_WWAC, 
           ( (Total_EV.total_EV * 3.938725) + (Total_DV.total_DV * Cost_ofDebt.Cost_ofDebt) * (1 - Tax.TaxRate) ) AS WWAC
    FROM Total_EV 
    INNER JOIN Total_DV ON Total_EV.Tahun_EV = Total_DV.Tahun_DV
    INNER JOIN Cost_ofDebt ON Total_DV.Tahun_DV = Cost_ofDebt.Tahun_hutang
    INNER JOIN Tax ON Cost_ofDebt.Tahun_hutang = Tax.Tahun_EBT
),
expense AS (
    SELECT 
        YEAR(ji.created_at) AS Tahun,
        SUM(ji.debit) - SUM(ji.credit) AS total_expense
    FROM journal_items ji
    INNER JOIN chart_of_accounts coa ON ji.account = coa.id
    WHERE coa.type = 5
    GROUP BY YEAR(ji.created_at)
),
growth_rate AS (
    SELECT 
        r1.Tahun AS Tahun,
        r1.total_revenue,
        r2.total_revenue AS revenue_sebelum,
        ((r1.total_revenue - r2.total_revenue) / r2.total_revenue) AS nilai_G
    FROM revenue r1
    LEFT JOIN revenue r2 ON r1.Tahun = r2.Tahun + 1
),
rerata_g AS(
    SELECT 
        growth_rate.Tahun AS tahun, 
        FORMAT(revenue.total_revenue, 2, 'id_ID') AS total_revenue,
        CONVERT(AVG(growth_rate.nilai_G), DECIMAL(3,1)) AS rerata_presentase_g
    FROM growth_rate 
    INNER JOIN revenue ON growth_rate.Tahun = revenue.Tahun
    GROUP BY growth_rate.Tahun
),
Param_FCF AS (
    SELECT  
        YEAR(ji.created_at) AS Tahun,
        SUM(CASE 
                WHEN coat.id = 1 
                THEN ji.debit - ji.credit 
                ELSE 0 
            END) AS depreciation_amortization,
        (SUM(CASE 
                WHEN coat.id = 1 AND coat_sub.name = 'Current Asset' 
                THEN ji.debit - ji.credit 
                ELSE 0 
            END) - 
        SUM(CASE 
                WHEN coat.id = 2 AND coat_sub.name = 'Current Liability' 
                THEN ji.credit - ji.debit 
                ELSE 0 
            END)
        ) AS change_in_working_capital,
        SUM(CASE 
                WHEN coat.id = 1 AND coat_sub.name = 'Fixed Asset' 
                THEN ji.debit - ji.credit 
                ELSE 0 
            END) AS CapEx
    FROM journal_items ji
    INNER JOIN chart_of_accounts coa ON ji.account = coa.id
    INNER JOIN chart_of_account_types coat ON coa.type = coat.id
    INNER JOIN chart_of_account_sub_types coat_sub ON coat.id = coat_sub.type
    GROUP BY YEAR(ji.created_at)
),
FCF AS(
    SELECT 
        Param_FCF.Tahun AS Tahun, 
        FORMAT(revenue.total_revenue, 2, 'id_ID') AS total_revenue, 
        FORMAT(expense.total_expense, 2, 'id_ID') AS total_expense, 
        FORMAT((revenue.total_revenue - expense.total_expense), 2, 'id_ID') AS EBT,
        FORMAT(
            (
                (revenue.total_revenue - expense.total_expense) + 
                Param_FCF.depreciation_amortization + 
                Param_FCF.change_in_working_capital - 
                Param_FCF.CapEx
            ), 2, 'id_ID'
        ) AS free_cash_flow
    FROM Param_FCF 
    LEFT JOIN revenue ON Param_FCF.Tahun = revenue.Tahun
    LEFT JOIN expense ON Param_FCF.Tahun = expense.Tahun
    LEFT JOIN growth_rate ON Param_FCF.Tahun = growth_rate.Tahun
),
FCF_predik AS(
    SELECT 
        FCF.Tahun AS tahun_predik, 
        FCF.free_cash_flow AS FCF_Akhir,
        (FCF.free_cash_flow * (1 + rg.rerata_presentase_g)) AS FCF_proyeksi
    FROM FCF
    INNER JOIN rerata_g rg ON FCF.Tahun = rg.tahun
    WHERE FCF.Tahun = (SELECT MAX(Tahun) FROM FCF)
    UNION ALL
    SELECT 
        FCF.Tahun + 1 AS tahun_predik,
        (FCF.free_cash_flow * (1 + rg.rerata_presentase_g)) AS FCF_proyeksi,
        NULL AS FCF_Akhir
    FROM FCF
    LEFT JOIN rerata_g rg ON FCF.Tahun = rg.tahun
    WHERE FCF.Tahun < 2028
)
SELECT 
    FCF.Tahun AS tahun,  
    FCF.total_revenue AS revenue, 
    FCF.total_expense AS total_expense, 
    FCF.EBT AS EBT, 
    FCF.free_cash_flow AS FCF, 
    rg.rerata_presentase_g AS rerata_g_annual,
    FCF_predik.FCF_Akhir / POWER(1 + rg.rerata_presentase_g, FCF_predik.tahun_predik - 2023) AS present_value_fcf,
    -- TV method Gordon Growth Model sampai 2028
    (FCF_predik.FCF_proyeksi * (1 + rg.rerata_presentase_g)) / (WWAC.WWAC - rg.rerata_presentase_g) AS terminal_value,
    -- Hitung PV of FCF
    ((FCF_predik.FCF_proyeksi * (1 + rg.rerata_presentase_g)) / (WWAC.WWAC - rg.rerata_presentase_g)) / POWER(1 + WWAC.WWAC, FCF_predik.tahun_predik - 2023) AS present_value_terminal_value
FROM FCF 
LEFT JOIN rerata_g rg ON FCF.Tahun = rg.tahun
INNER JOIN Param_FCF ON FCF.Tahun = Param_FCF.Tahun
LEFT JOIN FCF_predik ON Param_FCF.Tahun = FCF_predik.tahun_predik
LEFT JOIN WWAC ON FCF.Tahun = WWAC.Tahun_WWAC;