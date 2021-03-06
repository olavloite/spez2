/*
 * Copyright 2020 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     https://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
import ch.qos.logback.classic.filter.ThresholdFilter
jmxConfigurator()

// make changes for dev appender here
appender("DEV-CONSOLE", ConsoleAppender) {
  withJansi = true

  encoder(PatternLayoutEncoder) {
    pattern = "%-4relative [%thread] %-5level %logger{30} - %msg%n"
    outputPatternAsHeader = false
  }
}

// make changes for prod appender here
appender("PROD-CONSOLE", ConsoleAppender) {
  withJansi = true

}

// used for logging during test coverage
appender("DEVNULL", FileAppender) {
  file = "/dev/null"
  encoder(PatternLayoutEncoder) {
    pattern = "%-4relative [%thread] %-5level %logger{30} - %msg%n"
    outputPatternAsHeader = false
  }
}

logger("com", INFO)
logger("com.google", INFO)
logger("com.google.spannerclient", INFO)
logger("com.google.spannerclient.Database", INFO)
logger("com.google.spannerclient.GrpcClient", INFO)
logger("com.google.spannerclient.Spanner", INFO)
logger("com.google.spannerclient.Util", INFO)
logger("com.google.spez", INFO)
logger("com.google.spez.cdc", INFO)
logger("com.google.spez.cdc.DisruptorHandler", INFO)
logger("com.google.spez.cdc.Main", INFO)
logger("com.google.spez.cdc.WorkStealingHandler", INFO)
logger("com.google.spez.core", INFO)
logger("com.google.spez.core.SpannerTailer", INFO)
logger("com.google.spez.core.Spez", INFO)
logger("io", INFO)
logger("io.netty", INFO)
logger("io.netty.buffer", INFO)
logger("io.netty.buffer.AbstractByteBuf", INFO)
logger("io.netty.buffer.ByteBufUtil", INFO)
logger("io.netty.buffer.PoolThreadCache", INFO)
logger("io.netty.buffer.PooledByteBufAllocator", INFO)
logger("io.netty.channel", INFO)
logger("io.netty.channel.DefaultChannelPipeline", OFF)
logger("io.netty.channel.MultithreadEventLoopGroup", INFO)
logger("io.netty.channel.nio", INFO)
logger("io.netty.channel.nio.NioEventLoop", INFO)
logger("io.netty.handler", INFO)
logger("io.netty.handler.ssl", INFO)
logger("io.netty.handler.ssl.CipherSuiteConverter", OFF)
logger("io.netty.handler.ssl.OpenSsl", INFO)
logger("io.netty.handler.ssl.OpenSslX509TrustManagerWrapper", INFO)
logger("io.netty.handler.ssl.ReferenceCountedOpenSslClientContext", INFO)
logger("io.netty.handler.ssl.ReferenceCountedOpenSslContext", INFO)
logger("io.netty.util", INFO)
logger("io.netty.util.Recycler", INFO)
logger("io.netty.util.ResourceLeakDetector", INFO)
logger("io.netty.util.ResourceLeakDetectorFactory", INFO)
logger("io.netty.util.concurrent", INFO)
logger("io.netty.util.concurrent.AbstractEventExecutor", INFO)
logger("io.netty.util.concurrent.DefaultPromise", INFO)
logger("io.netty.util.concurrent.DefaultPromise.rejectedExecution", INFO)
logger("io.netty.util.concurrent.GlobalEventExecutor", INFO)
logger("io.netty.util.concurrent.SingleThreadEventExecutor", INFO)
logger("io.netty.util.internal", INFO)
logger("io.netty.util.internal.CleanerJava9", INFO)
logger("io.netty.util.internal.InternalThreadLocalMap", INFO)
logger("io.netty.util.internal.NativeLibraryLoader", OFF)
logger("io.netty.util.internal.PlatformDependent", INFO)
logger("io.netty.util.internal.PlatformDependent0", INFO)
logger("io.netty.util.internal.SystemPropertyUtil", INFO)
logger("io.netty.util.internal.logging", INFO)
logger("io.netty.util.internal.logging.InternalLoggerFactory", INFO)


switch (System.getProperty("PRICE-ENV")) {
  case "PROD":
    root(toLevel(System.getProperty("PRICE-LOGLEVEL"), WARN), ["PROD-CONSOLE"])
    break
  case "TEST-COVERAGE":
    root(ALL, ["DEVNULL"])
    break
  case "DEV":
  default:
    root(ALL, ["DEV-CONSOLE"])
    break
}

