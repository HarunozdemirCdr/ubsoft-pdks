// Gerçekçi yurt saha senaryosu (1, 2, 4, 6 kişilik odalar, 21 günlük hareketler, zengin izinler).
// Kullanım:
//   node tool/seed_realistic_dorm.cjs --dry-run
//   node tool/seed_realistic_dorm.cjs --apply

const fs = require('node:fs');
const path = require('node:path');
const auth = require(path.join(process.env.APPDATA, 'npm/node_modules/firebase-tools/lib/auth.js'));

const apply = process.argv.includes('--apply');
const project = 'ubsoft-pdks';
const tid = 'turgev-demo';
const root = `projects/${project}/databases/(default)/documents/`;
const base = `https://firestore.googleapis.com/v1/${root.slice(0, -1)}`;
const demoTag = 'realistic-dorm-v2';

let token;

async function req(url, method = 'GET', body = null) {
  const r = await fetch(url, {
    method,
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    ...(body ? { body: JSON.stringify(body) } : {}),
  });
  if (!r.ok) {
    throw new Error(`HTTP ${r.status} ${url}: ${await r.text()}`);
  }
  return r.json();
}

const decode = (v) => {
  if (!v) return null;
  if (v.stringValue !== undefined) return v.stringValue;
  if (v.timestampValue !== undefined) return v.timestampValue;
  if (v.integerValue !== undefined) return Number(v.integerValue);
  if (v.doubleValue !== undefined) return Number(v.doubleValue);
  if (v.booleanValue !== undefined) return v.booleanValue;
  if (v.arrayValue !== undefined) return (v.arrayValue.values || []).map(decode);
  if (v.mapValue !== undefined) {
    return Object.fromEntries(
      Object.entries(v.mapValue.fields || {}).map(([k, x]) => [k, decode(x)])
    );
  }
  return null;
};

const encode = (v) => {
  if (v === null || v === undefined) return { nullValue: null };
  if (v instanceof Date) return { timestampValue: v.toISOString() };
  if (typeof v === 'string') return { stringValue: v };
  if (typeof v === 'boolean') return { booleanValue: v };
  if (typeof v === 'number') {
    return Number.isInteger(v) ? { integerValue: String(v) } : { doubleValue: v };
  }
  if (Array.isArray(v)) return { arrayValue: { values: v.map(encode) } };
  return {
    mapValue: {
      fields: Object.fromEntries(Object.entries(v).map(([k, x]) => [k, encode(x)])),
    },
  };
};

const fields = (o) => Object.fromEntries(Object.entries(o).map(([k, v]) => [k, encode(v)]));
const plain = (d) => Object.fromEntries(Object.entries(d.fields || {}).map(([k, v]) => [k, decode(v)]));

async function list(col) {
  const docs = [];
  let page = '';
  do {
    const r = await req(
      `${base}/tenants/${tid}/${col}?pageSize=1000${page ? `&pageToken=${encodeURIComponent(page)}` : ''}`
    );
    docs.push(...(r.documents || []));
    page = r.nextPageToken || '';
  } while (page);
  return docs;
}

// 1, 2, 4 ve 6 kişilik odalara yerleştirilmiş gerçekçi öğrenciler
const roster = [
  // 1 kişilik odalar (101 = Elif Yılmaz zaten mevcut, burada room=101 olarak güncellenecek)
  { uid: 'seed-student-01', name: 'Zeynep Kaya', room: '102', num: '2026003' },
  { uid: 'seed-student-02', name: 'Merve Arslan', room: '103', num: '2026004' },
  { uid: 'seed-student-03', name: 'Büşra Çelik', room: '104', num: '2026005' },

  // 2 kişilik odalar (201 - 205)
  { uid: 'seed-student-04', name: 'Sümeyye Şahin', room: '201', num: '2026006' },
  { uid: 'seed-student-19', name: 'Zehra Acar', room: '201', num: '2026021' },
  { uid: 'seed-student-05', name: 'Hümeyra Yıldız', room: '202', num: '2026007' },
  { uid: 'seed-student-20', name: 'Esma Yıldız', room: '202', num: '2026022' },
  { uid: 'seed-student-06', name: 'Esra Aydın', room: '203', num: '2026008' },
  { uid: 'seed-student-21', name: 'İrem Çelik', room: '203', num: '2026023' },
  { uid: 'seed-student-07', name: 'Ravza Öztürk', room: '204', num: '2026009' },
  { uid: 'seed-student-22', name: 'Betül Yavuz', room: '204', num: '2026024' },
  { uid: 'seed-student-08', name: 'Betül Karahan', room: '205', num: '2026010' },
  { uid: 'seed-student-23', name: 'Nisa Bulut', room: '205', num: '2026025' },

  // 4 kişilik odalar (301 - 306)
  { uid: 'seed-student-09', name: 'Sena Demirtaş', room: '301', num: '2026011' },
  { uid: 'seed-student-24', name: 'Aslı Yalçın', room: '301', num: '2026026' },
  { uid: 'seed-student-25', name: 'Ceren Duman', room: '301', num: '2026027' },
  { uid: 'seed-student-26', name: 'İlayda Kurt', room: '301', num: '2026028' },

  { uid: 'seed-student-10', name: 'İrem Kılıç', room: '302', num: '2026012' },
  { uid: 'seed-student-27', name: 'Ecrin Uçar', room: '302', num: '2026029' },
  { uid: 'seed-student-28', name: 'Sena Karaca', room: '302', num: '2026030' },
  { uid: 'seed-student-29', name: 'Derya Özkan', room: '302', num: '2026031' },

  { uid: 'seed-student-11', name: 'Kübra Doğan', room: '303', num: '2026013' },
  { uid: 'seed-student-30', name: 'Şevval Tekin', room: '303', num: '2026032' },
  { uid: 'seed-student-31', name: 'Havva Kaplan', room: '303', num: '2026033' },
  { uid: 'seed-student-32', name: 'Dila Erdem', room: '303', num: '2026034' },

  { uid: 'seed-student-12', name: 'Nisanur Aksoy', room: '304', num: '2026014' },
  { uid: 'seed-student-33', name: 'Sare Taş', room: '304', num: '2026035' },
  { uid: 'seed-student-34', name: 'Melike Sezer', room: '304', num: '2026036' },
  { uid: 'seed-student-35', name: 'Yasemin Keskin', room: '304', num: '2026037' },

  { uid: 'seed-student-13', name: 'Hatice Koç', room: '305', num: '2026015' },
  { uid: 'seed-student-36', name: 'Tuğba Akın', room: '305', num: '2026038' },
  { uid: 'seed-student-37', name: 'Ayşenur Korkmaz', room: '305', num: '2026039' },
  { uid: 'seed-student-38', name: 'Hilal Baş', room: '305', num: '2026040' },

  { uid: 'seed-student-14', name: 'Sıla Erdoğan', room: '306', num: '2026016' },
  { uid: 'seed-student-39', name: 'Rabia Güler', room: '306', num: '2026041' },
  { uid: 'seed-student-40', name: 'Gamze Şimşek', room: '306', num: '2026042' },
  { uid: 'seed-student-41', name: 'Elanur Çakır', room: '306', num: '2026043' },

  // 6 kişilik odalar (401 - 404)
  { uid: 'seed-student-15', name: 'Ebrar Çetin', room: '401', num: '2026017' },
  { uid: 'seed-student-42', name: 'Meryem Eren', room: '401', num: '2026044' },
  { uid: 'seed-student-43', name: 'Zümra Polat', room: '401', num: '2026045' },
  { uid: 'seed-student-44', name: 'Hümeyra Şen', room: '401', num: '2026046' },
  { uid: 'seed-student-45', name: 'Kevser Yüksel', room: '401', num: '2026047' },
  { uid: 'seed-student-46', name: 'Beyza Doğanay', room: '401', num: '2026048' },

  { uid: 'seed-student-16', name: 'Zümra Yalçın', room: '402', num: '2026018' },
  { uid: 'seed-student-47', name: 'Semanur Aktaş', room: '402', num: '2026049' },
  { uid: 'seed-student-48', name: 'Nurefşan Aslan', room: '402', num: '2026050' },
  { uid: 'seed-student-49', name: 'Rümeysa Işık', room: '402', num: '2026051' },
  { uid: 'seed-student-50', name: 'Azra Polatdemir', room: '402', num: '2026052' },
  { uid: 'seed-student-51', name: 'Buse Koca', room: '402', num: '2026053' },

  { uid: 'seed-student-17', name: 'Asude Gürbüz', room: '403', num: '2026019' },
  { uid: 'seed-student-52', name: 'Fatma Nur Bozkurt', room: '403', num: '2026054' },
  { uid: 'seed-student-53', name: 'Feyza Tunç', room: '403', num: '2026055' },
  { uid: 'seed-student-54', name: 'Sudem Özer', room: '403', num: '2026056' },
  { uid: 'seed-student-55', name: 'Melek Sarı', room: '403', num: '2026057' },
  { uid: 'seed-student-56', name: 'Nehir Karataş', room: '403', num: '2026058' },

  { uid: 'seed-student-18', name: 'Melike Taşdemir', room: '404', num: '2026020' },
  { uid: 'seed-student-57', name: 'Aleyna Kılıçarslan', room: '404', num: '2026059' },
  { uid: 'seed-student-58', name: 'Zeynep Sude Avcı', room: '404', num: '2026060' },
  { uid: 'seed-student-59', name: 'İklimya Kurtuluş', room: '404', num: '2026061' },
  { uid: 'seed-student-60', name: 'Rana Ünal', room: '404', num: '2026062' },
  { uid: 'seed-student-61', name: 'Tuğçe Demirci', room: '404', num: '2026063' },
];

// Şu an dışarıda / izinli / geciken / kayıtsız dağılımı (24 Kasım 2026 saha profili)
const uninitializedUids = new Set(['seed-student-23', 'seed-student-61']);
const activeLeaveSpecs = {
  'seed-student-04': { cat: 'Evci izni', dest: 'Ankara / Çankaya', name: 'Fatma Şahin', rel: 'Anne', phone: '0532 411 22 10', reason: 'Hafta içi aile yanı evci izni', daysFwd: 2 },
  'seed-student-11': { cat: 'Aile ziyareti', dest: 'Bursa / Nilüfer', name: 'Mustafa Doğan', rel: 'Baba', phone: '0533 618 44 09', reason: 'Aile ziyareti için şehir dışı izin', daysFwd: 3 },
  'seed-student-21': { cat: 'Sağlık', dest: 'İstanbul / Üsküdar', name: 'Selma Çelik', rel: 'Teyze', phone: '0542 309 18 75', reason: 'Hastane kontrolü ve istirahat', daysFwd: 1 },
  'seed-student-28': { cat: 'Evci izni', dest: 'Kocaeli / İzmit', name: 'Kemal Karaca', rel: 'Dayı', phone: '0535 740 55 31', reason: 'Dayısının yanında hafta sonu öncesi evci', daysFwd: 2 },
  'seed-student-35': { cat: 'Staj / Okul', dest: 'Sakarya / Serdivan', name: 'Ayşe Keskin', rel: 'Abla', phone: '0505 881 12 40', reason: 'Bölüm laboratuvar ve saha çalışması', daysFwd: 1 },
  'seed-student-44': { cat: 'Aile ziyareti', dest: 'Eskişehir / Odunpazarı', name: 'Hasan Şen', rel: 'Baba', phone: '0536 229 63 14', reason: 'Baba ziyareti', daysFwd: 2 },
  'seed-student-52': { cat: 'Evci izni', dest: 'İstanbul / Pendik', name: 'Emine Bozkurt', rel: 'Anne', phone: '0538 914 07 28', reason: 'Anne yanında aile izni', daysFwd: 2 },
  'seed-student-59': { cat: 'Özel mazeret', dest: 'Tekirdağ / Süleymanpaşa', name: 'Orhan Kurtuluş', rel: 'Amca', phone: '0544 512 90 11', reason: 'Ailevi nikah töreni katılımı', daysFwd: 3 },
};
const overdueUids = new Set([
  'seed-student-02',
  'seed-student-10',
  'seed-student-24',
  'seed-student-31',
  'seed-student-42',
  'seed-student-48',
  'seed-student-55',
]);
const outsideNormalUids = new Set([
  'seed-student-06',
  'seed-student-14',
  'seed-student-20',
  'seed-student-27',
  'seed-student-36',
  'seed-student-43',
  'seed-student-49',
  'seed-student-56',
]);

async function main() {
  const account = auth.getAllAccounts().find((a) => a.user.email === 'harun123gimba@gmail.com');
  if (!account) throw new Error('Yetkili Firebase CLI hesabı bulunamadı.');
  token = (await auth.getAccessToken(account.tokens.refresh_token, ['https://www.googleapis.com/auth/cloud-platform'])).access_token;

  const tenantDoc = await req(`${base}/tenants/${tid}`);
  const tenantPlain = plain(tenantDoc);
  const policy = tenantPlain.settings?.dormPolicy || {
    hours: { earliestExit: 360, latestEntry: 1350, earliestEntry: 420, enabled: true },
    tolerance: 10,
    weekdays: {},
    exceptions: {},
  };

  const [existingUsers, existingAtt, existingDays, existingPres, existingLeaves, existingLocks] = await Promise.all([
    list('users'),
    list('attendance'),
    list('attendanceDays'),
    list('presence'),
    list('leaves'),
    list('leaveLocks'),
  ]);

  const now = new Date();
  const localNowMs = now.getTime() + 3 * 3600000;
  const todayStr = new Date(localNowMs).toISOString().slice(0, 10);
  const dayKey = (offset) => new Date(Date.parse(`${todayStr}T00:00:00Z`) + offset * 86400000).toISOString().slice(0, 10);
  const at = (offset, minute) => new Date(Date.parse(`${dayKey(offset)}T00:00:00+03:00`) + minute * 60000);

  const actorDoc = existingUsers.find((d) => d.fields.email?.stringValue === 'mudire@turgevdemo.com');
  const actorUid = actorDoc ? actorDoc.name.split('/').at(-1) : 'hRoXrTHy3QTjW4lYSwqLV08LOfI3';

  // Silinecek eski sentetik veriler (Yalnız seed-student-* ve seed-att-*! Elif Yılmaz, Enes ve Müdire ASLA silinmez!)
  const seedStudentSet = new Set(roster.map((r) => r.uid));
  const deletes = [];
  for (const d of existingAtt) {
    const id = d.name.split('/').at(-1);
    const uid = decode(d.fields.userId);
    if (seedStudentSet.has(uid) || id.startsWith('seed-att-')) {
      deletes.push(d.name);
    }
  }
  for (const d of existingDays) {
    const uid = decode(d.fields.userId);
    if (seedStudentSet.has(uid)) deletes.push(d.name);
  }
  for (const d of existingPres) {
    const uid = d.name.split('/').at(-1);
    if (seedStudentSet.has(uid)) deletes.push(d.name);
  }
  for (const d of existingLeaves) {
    const id = d.name.split('/').at(-1);
    if (id.startsWith('seed-leave-')) deletes.push(d.name);
  }
  for (const d of existingLocks) {
    const uid = d.name.split('/').at(-1);
    if (seedStudentSet.has(uid)) deletes.push(d.name);
  }

  const writes = [];
  const putDoc = (col, id, data) => {
    writes.push({
      update: {
        name: `${root}tenants/${tid}/${col}/${id}`,
        fields: fields(data),
      },
    });
  };

  // Elif Yılmaz'a oda 101 ve öğrenci no 2026001 ekle (hareketlerine hiç dokunma)
  const elifDoc = existingUsers.find((d) => d.fields.email?.stringValue === 'ogrenci1@turgevdemo.com');
  if (elifDoc) {
    writes.push({
      update: {
        name: elifDoc.name,
        fields: fields({ room: '101', studentNumber: '2026001', updatedAt: now }),
      },
      updateMask: { fieldPaths: ['room', 'studentNumber', 'updatedAt'] },
    });
  }

  let generatedEvents = 0;
  let generatedDays = 0;
  let generatedLeaves = 0;
  const stats = { inside: 0, outside: 0, unknown: 0, overdue: 0, onLeave: 0 };

  for (let idx = 0; idx < roster.length; idx++) {
    const s = roster[idx];
    putDoc('users', s.uid, {
      uid: s.uid,
      email: `${s.uid}@turgevdemo.com`,
      displayName: s.name,
      tenantId: tid,
      role: 'staff',
      status: 'active',
      permissions: {},
      studentNumber: s.num,
      room: s.room,
      note: `${s.room} no'lu oda öğrencisi`,
      createdAt: at(-25, 600),
      updatedAt: now,
      demoSource: demoTag,
    });

    if (uninitializedUids.has(s.uid)) {
      stats.unknown++;
      continue;
    }

    const events = [];
    const pushEv = (offset, minute, type, opts = {}) => {
      const t = at(offset, minute);
      if (t > now) return;
      const dKey = new Date(t.getTime() + 10800000).toISOString().slice(0, 10);
      const id = `seed-att-v2-${s.uid}-${dKey}-${String(minute).padStart(4, '0')}-${type}`;
      const isPermitted = opts.permitted || false;
      const localMin = minute % 1440;
      const lateMin =
        type === 'in' && !isPermitted
          ? localMin < 360
            ? localMin + 1440 - 1360
            : Math.max(0, localMin - 1360)
          : 0;
      const earlyExit = type === 'out' && localMin < 360 && !isPermitted;
      const earlyEntry = type === 'in' && localMin < 420 && !isPermitted;
      const verdict = opts.verdict || 'verified';
      const dist = verdict === 'borderline' ? 142.0 : verdict === 'unavailable' ? null : 18.0 + (idx % 25);

      events.push({
        id,
        body: {
          tenantId: tid,
          userId: s.uid,
          userName: s.name,
          type,
          at: t,
          dateKey: dKey,
          checkpointId: type === 'in' ? 'giris' : 'cikis',
          checkpointName: type === 'in' ? '1. Durak Giriş' : '2. Durak Çıkış',
          checkpointCode: type === 'in' ? '1' : '2',
          verdict,
          ...(dist !== null ? { distanceMeters: dist } : {}),
          radiusMeters: 75,
          lateMinutes: lateMin,
          earlyExit,
          earlyEntry,
          permitted: isPermitted,
          cycleDate: dKey,
          policy,
          voided: false,
          schemaVersion: 2,
          demoSource: demoTag,
        },
      });
    };

    const hasBorderline = idx % 13 === 4;
    const hasUnavailable = idx % 17 === 7;
    const hasLateHistory = idx % 7 === 2;
    const hasEarlyExitHistory = idx % 9 === 3;

    // 20 gün önceki günden düne (-20 .. -1) hareketler
    for (let d = -20; d <= -1; d++) {
      // Dönüşü gecikenlerde dün (-1) çıkış yapıp geri dönmemiş bırak
      if (d === -1 && (overdueUids.has(s.uid) || activeLeaveSpecs[s.uid])) {
        pushEv(d, 495 + (idx % 7) * 8, 'out', {
          permitted: Boolean(activeLeaveSpecs[s.uid]),
        });
        continue;
      }

      const exitMin = hasEarlyExitHistory && d % 4 === 0 ? 335 + (idx % 15) : 480 + ((idx * 11 + Math.abs(d) * 7) % 130);
      const multi = (idx + Math.abs(d)) % 3 === 0;
      const vOpt = hasBorderline && d % 5 === 0 ? 'borderline' : hasUnavailable && d % 6 === 0 ? 'unavailable' : 'verified';

      pushEv(d, exitMin, 'out', { verdict: vOpt });

      if (multi) {
        const midIn = exitMin + 210;
        const midOut = midIn + 85;
        pushEv(d, midIn, 'in');
        pushEv(d, midOut, 'out');
      }

      const returnMin =
        hasLateHistory && d % 3 === 0
          ? 1382 + ((idx * 5) % 35) // 23:02 - 23:37 geç dönüş
          : 1120 + ((idx * 13 + Math.abs(d) * 9) % 195); // 18:40 - 21:55 normal dönüş
      pushEv(d, returnMin, 'in', { verdict: vOpt });
    }

    // Bugünkü hareketler (offset 0, 24 Kasım 2026)
    const isLeaveNow = Boolean(activeLeaveSpecs[s.uid]);
    const isOverdueNow = overdueUids.has(s.uid);
    const isOutsideNormalNow = outsideNormalUids.has(s.uid);

    if (!isLeaveNow && !isOverdueNow) {
      const todayOutMin = 490 + ((idx * 7) % 140);
      pushEv(0, todayOutMin, 'out');
      if (!isOutsideNormalNow) {
        if (idx % 4 === 0) {
          pushEv(0, 740 + (idx % 30), 'in');
          pushEv(0, 860 + (idx % 35), 'out');
        }
        const todayInMin = idx % 11 === 1 ? 1245 + (idx % 30) : 1060 + ((idx * 17) % 195);
        // Şu ana (yaklaşık 21:55) kadar gerçekleşmişse ekle
        pushEv(0, todayInMin, 'in');
      }
    }

    events.sort((a, b) => a.body.at - b.body.at);
    for (let k = 1; k < events.length; k++) {
      if (events[k].body.type === events[k - 1].body.type) {
        throw new Error(`Sıra çakışması: ${s.uid} indeks ${k}`);
      }
    }

    // Aktif izin + tarihçe izinleri
    if (isLeaveNow) {
      const sp = activeLeaveSpecs[s.uid];
      const fromD = at(-1, 450);
      const untilD = at(sp.daysFwd, 1260);
      for (const e of events) {
        if (e.body.at >= fromD && e.body.at <= untilD) {
          e.body.permitted = true;
          e.body.lateMinutes = 0;
          e.body.earlyExit = false;
          e.body.earlyEntry = false;
        }
      }
      const leaveId = `seed-leave-active-${s.uid}`;
      const leaveBody = {
        userId: s.uid,
        from: fromD,
        until: untilD,
        reason: sp.reason,
        category: sp.cat,
        destination: sp.dest,
        contactName: sp.name,
        contactRelation: sp.rel,
        contactPhone: sp.phone,
        revoked: false,
        actor: actorUid,
        createdAt: at(-2, 700),
        updatedAt: now,
        demoSource: demoTag,
      };
      putDoc('leaves', leaveId, leaveBody);
      putDoc('leaveLocks', s.uid, { ...leaveBody, leaveId });
      generatedLeaves++;
      stats.onLeave++;
    } else if (idx === 15 || idx === 25 || idx === 38) {
      // Geçmişte tamamlanmış örnek izinler
      const leaveId = `seed-leave-past-${s.uid}`;
      putDoc('leaves', leaveId, {
        userId: s.uid,
        from: at(-10, 480),
        until: at(-8, 1200),
        reason: idx === 15 ? 'Aile ziyareti (tamamlandı)' : idx === 25 ? 'Diş tedavisi izni' : 'Hafta sonu evci izni',
        category: idx === 25 ? 'Sağlık' : 'Evci izni',
        destination: idx === 15 ? 'Konya / Selçuklu' : idx === 25 ? 'İstanbul / Fatih' : 'Balıkesir / Altıeylül',
        contactName: idx === 15 ? 'Ahmet Çetin' : idx === 25 ? 'Münevver Duman' : 'Zeki Baş',
        contactRelation: idx === 25 ? 'Anne' : 'Baba',
        contactPhone: '0532 555 10 2' + (idx % 9),
        revoked: false,
        actor: actorUid,
        createdAt: at(-11, 600),
        updatedAt: at(-8, 1200),
        demoSource: demoTag,
      });
      generatedLeaves++;
    } else if (idx === 19 || idx === 45) {
      // Gelecek planlı veya iptal edilmiş izinler
      const isFuture = idx === 19;
      const leaveId = `seed-leave-${isFuture ? 'future' : 'revoked'}-${s.uid}`;
      const lBody = {
        userId: s.uid,
        from: at(isFuture ? 2 : -4, 480),
        until: at(isFuture ? 4 : -2, 1260),
        reason: isFuture ? 'Önümüzdeki hafta sonu aile evci izni' : 'Plan değişikliği nedeniyle iptal edildi',
        category: 'Aile ziyareti',
        destination: isFuture ? 'İzmir / Bornova' : 'Ankara / Yenimahalle',
        contactName: isFuture ? 'Halil Yıldız' : 'Neriman Yüksel',
        contactRelation: isFuture ? 'Baba' : 'Anne',
        contactPhone: '0533 444 98 76',
        revoked: !isFuture,
        ...(isFuture ? {} : { revokedBy: actorUid }),
        actor: actorUid,
        createdAt: at(-5, 650),
        updatedAt: now,
        demoSource: demoTag,
      };
      putDoc('leaves', leaveId, lBody);
      if (isFuture) putDoc('leaveLocks', s.uid, { ...lBody, leaveId });
      generatedLeaves++;
    }

    for (const ev of events) {
      putDoc('attendance', ev.id, ev.body);
      generatedEvents++;
    }

    const byDay = Map.groupBy(events, (e) => e.body.dateKey);
    for (const [dk, listDay] of byDay) {
      const ins = listDay.filter((e) => e.body.type === 'in');
      const outs = listDay.filter((e) => e.body.type === 'out');
      let openAt = null;
      let workedMinutes = 0;
      for (const e of listDay) {
        if (e.body.type === 'in') openAt = e.body.at;
        else if (openAt) {
          workedMinutes += Math.floor((e.body.at - openAt) / 60000);
          openAt = null;
        }
      }
      putDoc('attendanceDays', `${s.uid}_${dk}`, {
        tenantId: tid,
        userId: s.uid,
        userName: s.name,
        dateKey: dk,
        firstEntryAt: ins[0]?.body.at ?? null,
        lastEntryAt: ins.at(-1)?.body.at ?? null,
        lastExitAt: outs.at(-1)?.body.at ?? null,
        entryCount: ins.length,
        exitCount: outs.length,
        workedMinutes,
        open: listDay.at(-1).body.type === 'in',
        late: ins.some((e) => e.body.lateMinutes > 0),
        worstVerdict: listDay[0].body.verdict,
        updatedAt: now,
      });
      generatedDays++;
    }

    const last = events.at(-1);
    const inside = last.body.type === 'in';
    stats[inside ? 'inside' : 'outside']++;
    if (isOverdueNow) stats.overdue++;

    putDoc('presence', s.uid, {
      userId: s.uid,
      inside,
      eventId: last.id,
      at: last.body.at,
      checkpoint: last.body.checkpointName,
      revision: events.length,
      lateMinutes: last.body.lateMinutes,
      earlyExit: last.body.earlyExit,
      earlyEntry: last.body.earlyEntry,
      permitted: last.body.permitted,
    });
  }

  // Tenant counters güncelle (63 aktif öğrenci + 1 yönetici = 64 toplam kullanıcı)
  const adminCount = existingUsers.filter((d) => decode(d.fields.role) === 'admin').length;
  writes.push({
    update: {
      name: tenantDoc.name,
      fields: fields({
        counters: {
          ...(tenantPlain.counters || {}),
          userCount: roster.length + 2 + adminCount,
        },
        updatedAt: now,
      }),
    },
    updateMask: { fieldPaths: ['counters', 'updatedAt'] },
  });

  const summary = {
    mode: apply ? 'apply' : 'dry-run',
    targetTenant: tid,
    rooms: { onePerson: 4, twoPerson: 5, fourPerson: 6, sixPerson: 4, enesSpecialRoom58: 1 },
    seededStudents: roster.length,
    preservedRealStudents: 2,
    generatedEvents,
    generatedDays,
    generatedLeaves,
    deletesPlanned: deletes.length,
    writesPlanned: writes.length,
    liveStates: stats,
  };
  console.log(JSON.stringify(summary, null, 2));

  if (!apply) return;

  const backupDir = path.resolve('.local-backups');
  fs.mkdirSync(backupDir, { recursive: true });
  const backupFile = path.join(backupDir, `before-realistic-dorm-${now.toISOString().replaceAll(':', '-')}.json`);
  fs.writeFileSync(
    backupFile,
    JSON.stringify(
      {
        tenant: tenantDoc,
        users: existingUsers,
        presence: existingPres,
        leaves: existingLeaves,
        attendanceCount: existingAtt.length,
      },
      null,
      2
    )
  );

  // Önce eski seed kayıtlarını temizle (batch 200)
  const deleteOps = deletes.map((name) => ({ delete: name }));
  for (let i = 0; i < deleteOps.length; i += 200) {
    await req(`${base}:commit`, 'POST', { writes: deleteOps.slice(i, i + 200) });
  }
  // Yeni verileri yaz (batch 200)
  for (let i = 0; i < writes.length; i += 200) {
    await req(`${base}:commit`, 'POST', { writes: writes.slice(i, i + 200) });
  }

  console.log(JSON.stringify({ applied: true, backupFile }, null, 2));
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
