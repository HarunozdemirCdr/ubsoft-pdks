import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubsoft_pdks/data/repositories/attendance_repository_impl.dart';
import 'package:ubsoft_pdks/data/repositories/auth_repository_impl.dart';
import 'package:ubsoft_pdks/data/repositories/checkpoint_repository_impl.dart';
import 'package:ubsoft_pdks/data/repositories/tenant_repository_impl.dart';
import 'package:ubsoft_pdks/data/repositories/user_repository_impl.dart';
import 'package:ubsoft_pdks/domain/repositories/attendance_repository.dart';
import 'package:ubsoft_pdks/domain/repositories/auth_repository.dart';
import 'package:ubsoft_pdks/domain/repositories/checkpoint_repository.dart';
import 'package:ubsoft_pdks/domain/repositories/tenant_repository.dart';
import 'package:ubsoft_pdks/domain/repositories/user_repository.dart';

/// Altyapı ve repository sağlayıcıları — uygulamanın bağımlılık kökü.
///
/// Testler yalnız buradaki iki temel sağlayıcıyı (`firebaseAuthProvider`,
/// `firestoreProvider`) sahteleriyle değiştirir; üstteki her katman
/// olduğu gibi çalışır.

final Provider<FirebaseAuth> firebaseAuthProvider = Provider<FirebaseAuth>(
  (ref) => FirebaseAuth.instance,
);

final Provider<FirebaseFirestore> firestoreProvider =
    Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);

final Provider<AuthRepository> authRepositoryProvider =
    Provider<AuthRepository>(
      (ref) => AuthRepositoryImpl(ref.watch(firebaseAuthProvider)),
    );

final Provider<UserRepository> userRepositoryProvider =
    Provider<UserRepository>(
      (ref) => UserRepositoryImpl(ref.watch(firestoreProvider)),
    );

final Provider<TenantRepository> tenantRepositoryProvider =
    Provider<TenantRepository>(
      (ref) => TenantRepositoryImpl(ref.watch(firestoreProvider)),
    );

final Provider<CheckpointRepository> checkpointRepositoryProvider =
    Provider<CheckpointRepository>(
      (ref) => CheckpointRepositoryImpl(ref.watch(firestoreProvider)),
    );

final Provider<AttendanceRepository> attendanceRepositoryProvider =
    Provider<AttendanceRepository>(
      (ref) => AttendanceRepositoryImpl(ref.watch(firestoreProvider)),
    );
