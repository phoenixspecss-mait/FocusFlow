//Login Exceptions

class UserNotFoundException implements Exception{}

class WrongPassAuthException implements Exception{}

//Register Exceptions

class EmailAlreadyInUseException implements Exception{}

class InvalidEmailException implements Exception{}

class WeakPassowrdExcetion implements Exception {}

//Generic Exceptions

class GenericAuthException implements Exception{}

class UserNotLoggedinException implements Exception{}