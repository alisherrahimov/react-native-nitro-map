#include <jni.h>
#include "nitromapOnLoad.hpp"

JNIEXPORT jint JNICALL JNI_OnLoad(JavaVM* vm, void*) {
  return margelo::nitro::nitromap::initialize(vm);
}
