-- ═══════════════════════════════════════════════════════
-- 祈癒職能治療所 · 長照居家復健管理系統完整資料庫腳本
-- 包含：完整欄位支援 + 行程模組 + 安全 RLS 防護
-- ═══════════════════════════════════════════════════════

-- 1. 員工帳號表
create table if not exists accounts (
  id bigint primary key,
  name text not null,
  role text default 'staff',
  username text unique not null,
  password text default 'managed-by-supabase-auth',
  job_role text default '物理治療師',
  id_no text default '',
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
  district text default '',
  unit_a text default '',
  address text,
  contact text,
  dx text,
  discharge text default 'no',
  first_free text default 'no',
  aa05 text default 'no',
  aa09 text default 'no',
  assigned_to bigint references accounts(id),
  assigned_staff jsonb default '[]',
  service_codes jsonb default '[]',
  closed boolean default false,
  closure jsonb,
  mgmt_goal jsonb,
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
  homework jsonb,
  c_code jsonb,
  status text default 'pending',
  comment text,
  closure_data jsonb
);

-- 4. 行程與待辦資料表
create table if not exists cal_events (
  id bigint primary key,
  title text not null,
  date text not null,
  type text default 'other',
  start_time text,
  end_time text,
  staff_id text,
  pat_id text,
  note text,
  created_at timestamptz default now()
);

create table if not exists cal_todos (
  id bigint primary key,
  title text not null,
  type text default 'other',
  due text,
  pat_id text,
  note text,
  done boolean default false,
  created_at timestamptz default now()
);

-- ═══════════════════════════════════════════════════════
-- 5. 啟用安全防護（Row Level Security）
-- ═══════════════════════════════════════════════════════
alter table accounts   enable row level security;
alter table patients   enable row level security;
alter table sessions   enable row level security;
alter table cal_events enable row level security;
alter table cal_todos  enable row level security;

-- 輔助驗證函數
create or replace function current_account_id()
returns text as $$
  select id::text from accounts
  where lower(username) = lower(split_part(auth.jwt() ->> 'email', '@', 1))
    and active = true
  limit 1;
$$ language sql stable security definer;

create or replace function is_manager()
returns boolean as $$
  select exists (
    select 1 from accounts
    where lower(username) = lower(split_part(auth.jwt() ->> 'email', '@', 1))
      and role = 'mgr'
      and active = true
  );
$$ language sql stable security definer;

-- Accounts 策略
create policy "登入者可讀取帳號" on accounts for select using (auth.role() = 'authenticated');
create policy "主管完全管理帳號" on accounts for all using (is_manager()) with check (is_manager());
create policy "員工僅能更新自己部分資料" on accounts for update using (id::text = current_account_id() and not is_manager()) with check (id::text = current_account_id() and role = 'staff');

-- Patients 策略
create policy "主管完全管理 patients" on patients for all using (is_manager()) with check (is_manager());
create policy "員工僅能讀取指派之個案" on patients for select using (
  auth.role() = 'authenticated' and (
    assigned_to::text = current_account_id() or (
      assigned_staff is not null and (
        assigned_staff::jsonb @> jsonb_build_array(current_account_id()) or
        (current_account_id() ~ '^[0-9]+$' and assigned_staff::jsonb @> jsonb_build_array(current_account_id()::bigint))
      )
    )
  )
);
create policy "員工可更新指派個案目標" on patients for update using (
  auth.role() = 'authenticated' and (
    assigned_to::text = current_account_id() or (
      assigned_staff is not null and (
        assigned_staff::jsonb @> jsonb_build_array(current_account_id()) or
        (current_account_id() ~ '^[0-9]+$' and assigned_staff::jsonb @> jsonb_build_array(current_account_id()::bigint))
      )
    )
  )
);

-- Sessions 策略
create policy "主管完全管理 sessions" on sessions for all using (is_manager()) with check (is_manager());
create policy "員工查看自己的服務紀錄" on sessions for select using (auth.role() = 'authenticated' and staff_id::text = current_account_id());
create policy "員工新增自己的服務紀錄" on sessions for insert with check (auth.role() = 'authenticated' and staff_id::text = current_account_id() and status = 'pending');
create policy "員工修改被退回的服務紀錄" on sessions for update using (auth.role() = 'authenticated' and staff_id::text = current_account_id() and (status = 'rejected' or status = 'pending')) with check (auth.role() = 'authenticated' and staff_id::text = current_account_id() and status = 'pending');

-- 行事曆與待辦策略
create policy "主管完全管理行事曆與待辦" on cal_events for all using (is_manager()) with check (is_manager());
create policy "員工查看與自己相關之行程" on cal_events for select using (auth.role() = 'authenticated' and (staff_id is null or staff_id::text = '' or staff_id::text = current_account_id()));
create policy "主管完全管理待辦" on cal_todos for all using (is_manager()) with check (is_manager());

-- ═══════════════════════════════════════════════════════
-- 6. 初始示範資料注入
-- ═══════════════════════════════════════════════════════
-- 插入主管帳號（admin）與員工帳號
insert into accounts (id, name, role, username, job_role, id_no, color, active) values
(0, '祈癒職能治療所', 'mgr', 'admin', '機構主管', '', '#1e3a5f', true),
(1, '王小明', 'staff', 'wang', '物理治療師', 'A123456789', '#1e3a5f', true),
(2, '李美玲', 'staff', 'li', '職能治療師', 'B234567890', '#0d6e6e', true),
(3, '陳志豪', 'staff', 'chen', '物理治療師', 'C345678901', '#553c9a', true)
on conflict (id) do update set 
  name = excluded.name, 
  role = excluded.role, 
  job_role = excluded.job_role,
  active = excluded.active;

-- 初始個案
insert into patients (id, name, id_no, birth, gender, econ, start_date, district, unit_a, address, contact, dx, assigned_to, assigned_staff, closed, short_goal, long_goal) values
('P001', '林○○', 'A123456789', '1948-03-15', '男', 'general', '2026-01-10', '信義區', '桃園長照中心', '台北市信義區○○路1號', '林○○（子）/0912-345-678', '腦中風後左側偏癱，行走功能受損', 1, '[1]', false,
 '{"name":"改善步行穩定性","desc":"目標4個月內能使用輔具獨立步行10公尺","items":["CA07","CA08"],"deadline":"2026-05-31","prog":45}',
 '{"name":"恢復功能性行走","desc":"目標一年內能在家中獨立移動","items":["CA07","CA08","CB03"],"deadline":"2026-12-31","prog":20}'),
('P002', '陳○○', 'B234567890', '1952-07-22', '女', 'mid-low', '2026-01-20', '大安區', '寬福護理之家', '台北市大安區○○路5號', '陳○○（女）/0922-111-222', '右側全膝關節置換術後，ROM受限', 1, '[1]', false,
 '{"name":"恢復膝關節活動度至120度","desc":"術後3個月達到功能性ROM","items":["CA07","CB03"],"deadline":"2026-04-30","prog":70}',
 '{"name":"回歸完全社區活動能力","desc":"能爬樓梯、外出購物","items":["CA07","CB03"],"deadline":"2026-10-31","prog":30}'),
('P003', '黃○○', 'C345678901', '1961-11-08', '男', 'low', '2026-02-01', '板橋區', '板橋衛生所', '新北市板橋區○○街10號', '黃○○（妻）/0933-222-333', '脊髓損傷T6不完全損傷', 2, '[2]', false,
 '{"name":"提升下肢肌力與轉位能力","desc":"能夠由坐到站，完成床到輪椅轉位","items":["CA07","CB01a","CB03"],"deadline":"2026-05-01","prog":35}',
 '{"name":"最大化功能獨立，回歸職場","desc":"能操作手動輪椅獨立生活","items":["CA07","CB01a","CB03","CB04"],"deadline":"2026-12-31","prog":15}'),
('P004', '蔡○○', 'D456789012', '1975-09-12', '男', 'general', '2026-03-01', '松山區', '台北長照中心', '台北市松山區○○路22號', '蔡○○（妻）/0955-444-555', '腰椎椎間盤突出術後，下背痛', 3, '[3]', false,
 '{"name":"緩解下背痛與強化核心","desc":"術後3個月恢復日常活動，VAS降至3分","items":["CA07","CA08"],"deadline":"2026-06-01","prog":60}',
 '{"name":"回歸工作崗位","desc":"完全回歸辦公室工作","items":["CA07","CA08","CB03"],"deadline":"2026-09-30","prog":30}')
on conflict (id) do nothing;

-- 初始紀錄
insert into sessions (id, pat_id, staff_id, date, start_time, end_time, sess_no, type, items, note, next_plan, status, comment) values
(1, 'P001', 1, '2026-03-05', '09:00', '10:00', 1, 'normal', '[{"code":"CA07","value":"40","note":"ROM改善"},{"code":"CA08","value":"20","note":"步態訓練"}]', '配合度良好，左下肢進步。', '繼續步態訓練', 'approved', '紀錄完整。'),
(2, 'P001', 1, '2026-03-12', '09:00', '10:00', 2, 'normal', '[{"code":"CA07","value":"40","note":"抗阻訓練"},{"code":"CA08","value":"30","note":"步行15公尺"}]', '步行距離增至15公尺。', '目標20公尺', 'approved', ''),
(3, 'P001', 1, '2026-03-19', '09:00', '10:00', 3, 'normal', '[{"code":"CA07","value":"45","note":"進階訓練"},{"code":"CA08","value":"30","note":"步行20公尺"}]', '步行20公尺達成！', '嘗試戶外練習', 'pending', ''),
(4, 'P002', 1, '2026-03-10', '11:00', '12:00', 1, 'normal', '[{"code":"CA07","value":"45","note":"ROM達100度"},{"code":"CB03","value":"30","note":"上下樓梯"}]', '術後恢復順利。', '加強下樓梯控制', 'approved', ''),
(5, 'P003', 2, '2026-03-08', '10:00', '11:00', 1, 'normal', '[{"code":"CA07","value":"40","note":"肌力3/5"},{"code":"CB01a","value":"30","note":"上肢訓練"}]', '首次服務，配合度高。', '繼續肌力訓練', 'approved', ''),
(6, 'P004', 3, '2026-03-15', '09:00', '10:00', 1, 'normal', '[{"code":"CA07","value":"40","note":"VAS 5分"},{"code":"CA08","value":"20","note":"核心訓練"}]', '術後第2週，疼痛VAS 5分。', '加強腹橫肌訓練', 'approved', ''),
(7, 'P004', 3, '2026-03-22', '09:00', '10:00', 2, 'normal', '[{"code":"CA07","value":"45","note":"VAS降至3分"},{"code":"CA08","value":"25","note":"功能訓練"}]', '疼痛改善，可完成橋式20下。', '加入站姿訓練', 'pending', '')
on conflict (id) do nothing;
