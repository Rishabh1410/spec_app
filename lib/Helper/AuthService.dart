import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rxdart/rxdart.dart';
import 'package:path/path.dart';
import 'package:spec_app/main.dart';
class AuthService{
  final FirebaseAuth _auth=FirebaseAuth.instance;
  final GoogleSignIn googleSignIn=GoogleSignIn();
  final Firestore _db=Firestore.instance;

  Observable<FirebaseUser> u;
  Observable<Map<String,dynamic>>profile;
  PublishSubject loading=PublishSubject();

  // constructor
  AuthService(){
        u=Observable(_auth.onAuthStateChanged);
        profile=u.switchMap((FirebaseUser u) {
          if(u!=null)
           { return _db.collection('users').document(u.uid).snapshots().map(
                (snap)=>snap.data);
           }
          else{
            return Observable.just({});
          }
        });
  }

  Future<FirebaseUser> signInWithGoogle() async{
    loading.add(true);
      final GoogleSignInAccount googleSignInAccount=await googleSignIn.signIn();
      final GoogleSignInAuthentication googleSignInAuthentication=await
          googleSignInAccount.authentication;

      final AuthCredential credential = GoogleAuthProvider.getCredential(
          accessToken: googleSignInAuthentication.accessToken,
          idToken:googleSignInAuthentication.idToken);
      final AuthResult authResult = await _auth.signInWithCredential(credential);

      final FirebaseUser user = authResult.user;
      updateUserData(user);
      loading.add(false);
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setBool('IsLoggedInGoogle',true);
    prefs.setBool('IsLoggedInFirebase',false);
      return user;
  }

  void updateUserData(FirebaseUser user) async {
    DocumentReference ref = _db.collection('users').document(user.uid);
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setBool('IsLoggedIn',true);
    return ref.setData({
      'uid': user.uid,
      'email': user.email,
      'photoURL': user.photoUrl,
      'displayName': user.displayName,
      'lastSeen': DateTime.now()
    }, merge: true);
  }

  void signOutGoogle() async{
    await googleSignIn.signOut();
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setBool('IsLoggedIn',false);
    print("User Sign Out");
  }

  Future<FirebaseUser>SignUp(name,surname,email,password,image) async {
    AuthResult result=await _auth.createUserWithEmailAndPassword(email:email, password: password);
    UserUpdateInfo info =UserUpdateInfo();
    info.displayName=name+" "+surname;
    String image_url=null;
    if(image!=null)
    {
      StorageReference ref=FirebaseStorage().ref().child('upload/${basename(image.path)}');
      StorageUploadTask uploadTask=ref.putFile(image);
      StorageTaskSnapshot snapshot=await uploadTask.onComplete;
      image_url=await snapshot.ref.getDownloadURL();
    }
    info.photoUrl=image_url;
    result.user.updateProfile(info);
    FirebaseUser u=result.user;
    if(u!=null)
    {
      _db.collection('users').document(u.uid).setData(
          {
            'uid':u.uid,
            'lastSeen':DateTime.now(),
            'photoURL':image_url,
            'email':email,
            'displayName':name+" "+surname,
          },merge: true);

      SharedPreferences prefs = await SharedPreferences.getInstance();
      prefs.setBool('IsLoggedInGoogle',false);
      prefs.setBool('IsLoggedInFirebase',true);
      prefs.setString('uid', u.uid);
      return u;
    }
  }

  Future<FirebaseUser>SignIn({email,password}) async
  {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if(email==null&&password==null)
    {
      FirebaseUser  u=await _auth.currentUser();
          if(u!=null)
            return u;
    }
    try{
      AuthResult result = await _auth
          .signInWithEmailAndPassword(email: email, password: password);
      user=result.user;
      prefs.setBool('IsLoggedInGoogle',false);
      prefs.setBool('IsLoggedInFirebase',true);
      return user;
    }
    catch(error) {
      return null;
    }
  }
}