# -*- coding: utf-8 -*-
"""Yayındaki güvenlik kurallarını gerçek hesaplarla sınar.

Bu projede kurallar için emülatör testi yok; doğrulama canlı sorgularla
yapılır. Betik gerçek bir istemci gibi davranır — Firebase Auth ile giriş
yapar ve Firestore'a o kullanıcının kimliğiyle sorar — dolayısıyla
`flutter test` içindeki sahte Firestore'un ATLADIĞI katmanı sınar.

Kullanım:
    python tool/verify_live.py

Yalnız okuma yapar; hiçbir veriyi değiştirmez.
"""
import datetime
import json
import sys
import urllib.error
import urllib.request

API_KEY = 'AIzaSyD3fYz9iQ7RKUpJ37sG9pAnUXy1MY0hL24'
PROJECT = 'ubsoft-pdks'
DOCS = (f'https://firestore.googleapis.com/v1/projects/{PROJECT}'
        '/databases/(default)/documents')
TENANT = 'demo-beyaz-yapi'

ADMIN = ('yonetici@beyazyapi.com', 'Pdks2026!')
STAFF = ('ahmet@beyazyapi.com', 'Pdks2026!')
OTHER_STAFF = ('mehmet@beyazyapi.com', 'Pdks2026!')

passed = 0
failed = 0


def check(name, ok, detail=''):
    global passed, failed
    if ok:
        passed += 1
        print('  [gecti]', name)
    else:
        failed += 1
        print('  [KALDI]', name, detail)


def sign_in(email, password):
    url = ('https://identitytoolkit.googleapis.com/v1/'
           f'accounts:signInWithPassword?key={API_KEY}')
    body = json.dumps({'email': email, 'password': password,
                       'returnSecureToken': True}).encode()
    req = urllib.request.Request(
        url, data=body, headers={'Content-Type': 'application/json'})
    data = json.load(urllib.request.urlopen(req))
    return data['idToken'], data['localId']


def get(token, path):
    """(belge, http_kodu) döner. Bulunamayan belge için (None, 404)."""
    req = urllib.request.Request(
        f'{DOCS}/{path}', headers={'Authorization': f'Bearer {token}'})
    try:
        return json.load(urllib.request.urlopen(req)), 200
    except urllib.error.HTTPError as e:
        return None, e.code


def query(token, body, parent=''):
    req = urllib.request.Request(
        f'{DOCS}{parent}:runQuery', data=json.dumps(body).encode(),
        headers={'Content-Type': 'application/json',
                 'Authorization': f'Bearer {token}'})
    try:
        rows = json.load(urllib.request.urlopen(req))
        return [r for r in rows if 'document' in r], 200
    except urllib.error.HTTPError as e:
        return None, e.code


def day_path(uid, date_key):
    return f'tenants/{TENANT}/attendanceDays/{uid}_{date_key}'


def own_day_key(token, uid):
    """Kişinin okutma yapmış bir gününün anahtarı; yoksa None."""
    rows, _ = query(token, {'structuredQuery': {
        'from': [{'collectionId': 'attendanceDays'}],
        'where': {'fieldFilter': {'field': {'fieldPath': 'userId'},
                                  'op': 'EQUAL',
                                  'value': {'stringValue': uid}}},
        'limit': 1,
    }}, f'/tenants/{TENANT}')
    if not rows:
        return None
    fields = rows[0]['document']['fields']
    return fields['dateKey']['stringValue']


def main():
    today = datetime.date.today().isoformat()

    print('1) Girisler')
    admin_token, admin_uid = sign_in(*ADMIN)
    staff_token, staff_uid = sign_in(*STAFF)
    other_token, other_uid = sign_in(*OTHER_STAFF)
    check('yonetici girisi', bool(admin_token))
    check('personel girisi', bool(staff_token))
    check('ikinci personel girisi', bool(other_token))

    print()
    print('2) Personel kendi gun ozetini okuyabiliyor')
    #
    # GERILEME TESTI. Gun ozeti ancak ilk okutmayla olusur. Kural belgenin
    # ALANINA bakip sahibini bulmaya calisirsa, olmayan belgede degerlendirme
    # patlar ve 403 doner: personel sabah uygulamayi actiginda kendi okutma
    # ekraninda "Bu islem icin yetkiniz yok" gorurdu. Dogru cevap 404'tur
    # ("belge yok"), 403 degil.
    _, code = get(staff_token, day_path(staff_uid, today))
    check('bugun (belge henuz yoksa) 403 DEGIL', code != 403,
          f'HTTP {code} -- kural olmayan belgenin alanina bakiyor')

    future = (datetime.date.today() + datetime.timedelta(days=400)).isoformat()
    _, code = get(staff_token, day_path(staff_uid, future))
    check('hic olmayacak bir gun 403 DEGIL', code != 403, f'HTTP {code}')

    existing = own_day_key(staff_token, staff_uid)
    check('kendi gunlerini sorgulayabiliyor', existing is not None)
    if existing:
        _, code = get(staff_token, day_path(staff_uid, existing))
        check('VAR OLAN kendi gununu okuyabiliyor', code == 200, f'HTTP {code}')

    print()
    print('3) Sinir hala kapali (kural gevsetilmedi)')
    #
    # Yukaridaki duzeltme "kimligin ilk parcasi benim uid'im mi" diye bakiyor.
    # Bu kisayolun BASKASININ gunune kapi acmadigi burada kanitlanir.
    other_existing = own_day_key(other_token, other_uid)
    if other_existing:
        _, code = get(staff_token, day_path(other_uid, other_existing))
        check('personel BASKASININ var olan gununu okuyamiyor', code == 403,
              f'beklenen 403, gelen {code}')

    _, code = get(staff_token, day_path(other_uid, future))
    check('personel BASKASININ olmayan gununu okuyamiyor', code == 403,
          f'beklenen 403, gelen {code}')

    rows, code = query(staff_token, {'structuredQuery': {
        'from': [{'collectionId': 'attendanceDays'}], 'limit': 5,
    }}, f'/tenants/{TENANT}')
    check('personel TUM kadronun gunlerini listeleyemiyor', code == 403,
          f'beklenen 403, gelen {code}')

    rows, code = query(staff_token, {'structuredQuery': {
        'from': [{'collectionId': 'checkpoints'}], 'limit': 5,
    }}, f'/tenants/{TENANT}')
    check('personel nokta LISTESINI goremiyor', code == 403,
          f'beklenen 403, gelen {code}')

    doc, code = get(staff_token, f'tenants/{TENANT}/qrIndex/1')
    check('personel QR kodunu cozebiliyor (okutma icin sart)', code == 200,
          f'HTTP {code}')

    print()
    print('4) Yonetici')
    if other_existing:
        _, code = get(admin_token, day_path(other_uid, other_existing))
        check('yonetici baskasinin gununu okuyabiliyor', code == 200,
              f'HTTP {code}')

    _, code = get(admin_token, day_path(other_uid, future))
    check('yonetici olmayan gunde de 403 almiyor', code != 403, f'HTTP {code}')

    rows, code = query(admin_token, {'structuredQuery': {
        'from': [{'collectionId': 'users'}]}}, f'/tenants/{TENANT}')
    check('yonetici kadroyu listeleyebiliyor', rows is not None,
          f'HTTP {code}')

    print()
    print(f'Sonuc: {passed} gecti, {failed} kaldi')
    return 1 if failed else 0


if __name__ == '__main__':
    sys.exit(main())
