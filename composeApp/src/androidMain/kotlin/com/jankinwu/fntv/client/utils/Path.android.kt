package com.jankinwu.fntv.client.utils

actual fun SystemPath.length(): Long {
    TODO("Not yet implemented")
}

actual fun SystemPath.isDirectory(): Boolean {
    TODO("Not yet implemented")
}

actual fun SystemPath.isRegularFile(): Boolean {
    TODO("Not yet implemented")
}

actual inline fun <T> SystemPath.useDirectoryEntries(block: (Sequence<SystemPath>) -> T): T {
    TODO("Not yet implemented")
}

actual fun SystemPath.moveDirectoryRecursively(
    target: SystemPath,
    onBeforeMove: ((SystemPath) -> Unit)?
) {
}

actual val SystemPath.absolutePath: String
    get() = TODO("Not yet implemented")

//actual fun SystemPaths.createTempDirectory(prefix: String): SystemPath {
//    TODO("Not yet implemented")
//}
//
//actual fun SystemPaths.createTempFile(
//    prefix: String,
//    suffix: String
//): SystemPath {
//    TODO("Not yet implemented")
//}