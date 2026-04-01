-- 祈癒職能治療所 · 居家復健管理系統
-- 在 Supabase SQL Editor 執行此腳本

-- 1. 員工帳號表
create table if not exists accounts (
  id bigint primary key,
  name text not null,
  role text default 'staff',
  username text unique not null,
  password text not null,
  job_role text default '物理治療師',
  color text default '#1e3a5f',
  active boolean default true
);

-- 2. 個案表
create table if not exists patients (
  id text primary key,
  name text not null,
  id_no text,
  birth text,
  gender text default '男',
  econ text default 'general',
  start_date text,
  address text,
  contact text,
  dx text,
  assigned_to bigint references accounts(id),
  closed boolean default false,
  closure jsonb,
  short_goal jsonb,
  long_goal jsonb
);

-- 3. 服務紀錄表
create table if not exists sessions (
  id bigint primary key,
  pat_id text references patients(id),
  staff_id bigint references accounts(id),
  date text not null,
  start_time text,
  end_time text,
  sess_no integer default 1,
  type text default 'normal',
  items jsonb default '[]',
  note text,
  next_plan text,
  status text default 'pending',
  comment text,
  closure_data jsonb
);

-- 4. 開放所有操作 (RLS off for simplicity)
alter table accounts disable row level security;
alter table patients disable row level security;
alter table sessions disable row level security;

-- 5. 初始員工資料
insert into accounts (id, name, role, username, password, job_role, color, active) values
(1, '王小明', 'staff', 'wang', '1234', '物理治療師', '#1e3a5f', true),
(2, '李美玲', 'staff', 'li', '1234', '職能治療師', '#0d6e6e', true),
(3, '陳志豪', 'staff', 'chen', '1234', '物理治療師', '#553c9a', true)
on conflict (id) do nothing;

-- 6. 初始個案資料
insert into patients (id, name, id_no, birth, gender, econ, start_date, address, contact, dx, assigned_to, closed, short_goal, long_goal) values
('P001', '林○○', 'A123456789', '1948-03-15', '男', 'general', '2026-01-10', '台北市信義區○○路1號', '林○○（子）/0912-345-678', '腦中風後左側偏癱，行走功能受損', 1, false,
 '{"name":"改善步行穩定性","desc":"目標4個月內能使用輔具獨立步行10公尺","items":["CA07","CA08"],"deadline":"2026-05-31","prog":45}',
 '{"name":"恢復功能性行走","desc":"目標一年內能在家中獨立移動","items":["CA07","CA08","CB03"],"deadline":"2026-12-31","prog":20}'),
('P002', '陳○○', 'B234567890', '1952-07-22', '女', 'mid-low', '2026-01-20', '台北市大安區○○路5號', '陳○○（女）/0922-111-222', '右側全膝關節置換術後，ROM受限', 1, false,
 '{"name":"恢復膝關節活動度至120度","desc":"術後3個月達到功能性ROM","items":["CA07","CB03"],"deadline":"2026-04-30","prog":70}',
 '{"name":"回歸完全社區活動能力","desc":"能爬樓梯、外出購物","items":["CA07","CB03"],"deadline":"2026-10-31","prog":30}'),
('P003', '黃○○', 'C345678901', '1961-11-08', '男', 'low', '2026-02-01', '新北市板橋區○○街10號', '黃○○（妻）/0933-222-333', '脊髓損傷T6不完全損傷', 2, false,
 '{"name":"提升下肢肌力與轉位能力","desc":"能夠由坐到站，完成床到輪椅轉位","items":["CA07","CB01a","CB03"],"deadline":"2026-05-01","prog":35}',
 '{"name":"最大化功能獨立，回歸職場","desc":"能操作手動輪椅獨立生活","items":["CA07","CB01a","CB03","CB04"],"deadline":"2026-12-31","prog":15}'),
('P004', '蔡○○', 'D456789012', '1975-09-12', '男', 'general', '2026-03-01', '台北市松山區○○路22號', '蔡○○（妻）/0955-444-555', '腰椎椎間盤突出術後，下背痛', 3, false,
 '{"name":"緩解下背痛與強化核心","desc":"術後3個月恢復日常活動，VAS降至3分","items":["CA07","CA08"],"deadline":"2026-06-01","prog":60}',
 '{"name":"回歸工作崗位","desc":"完全回歸辦公室工作","items":["CA07","CA08","CB03"],"deadline":"2026-09-30","prog":30}')
on conflict (id) do nothing;

-- 7. 初始服務紀錄
insert into sessions (id, pat_id, staff_id, date, start_time, end_time, sess_no, type, items, note, next_plan, status, comment) values
(1, 'P001', 1, '2026-03-05', '09:00', '10:00', 1, 'normal', '[{"code":"CA07","value":"40","note":"ROM改善"},{"code":"CA08","value":"20","note":"步態訓練"}]', '配合度良好，左下肢進步。', '繼續步態訓練', 'approved', '紀錄完整。'),
(2, 'P001', 1, '2026-03-12', '09:00', '10:00', 2, 'normal', '[{"code":"CA07","value":"40","note":"抗阻訓練"},{"code":"CA08","value":"30","note":"步行15公尺"}]', '步行距離增至15公尺。', '目標20公尺', 'approved', ''),
(3, 'P001', 1, '2026-03-19', '09:00', '10:00', 3, 'normal', '[{"code":"CA07","value":"45","note":"進階訓練"},{"code":"CA08","value":"30","note":"步行20公尺"}]', '步行20公尺達成！', '嘗試戶外練習', 'pending', ''),
(4, 'P002', 1, '2026-03-10', '11:00', '12:00', 1, 'normal', '[{"code":"CA07","value":"45","note":"ROM達100度"},{"code":"CB03","value":"30","note":"上下樓梯"}]', '術後恢復順利。', '加強下樓梯控制', 'approved', ''),
(5, 'P003', 2, '2026-03-08', '10:00', '11:00', 1, 'normal', '[{"code":"CA07","value":"40","note":"肌力3/5"},{"code":"CB01a","value":"30","note":"上肢訓練"}]', '首次服務，配合度高。', '繼續肌力訓練', 'approved', ''),
(6, 'P004', 3, '2026-03-15', '09:00', '10:00', 1, 'normal', '[{"code":"CA07","value":"40","note":"VAS 5分"},{"code":"CA08","value":"20","note":"核心訓練"}]', '術後第2週，疼痛VAS 5分。', '加強腹橫肌訓練', 'approved', ''),
(7, 'P004', 3, '2026-03-22', '09:00', '10:00', 2, 'normal', '[{"code":"CA07","value":"45","note":"VAS降至3分"},{"code":"CA08","value":"25","note":"功能訓練"}]', '疼痛改善，可完成橋式20下。', '加入站姿訓練', 'pending', '')
on conflict (id) do nothing;
