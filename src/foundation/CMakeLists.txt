set(sources
    Constants.h Constants.cpp
    NonCopyable.h
    AlignedArray.h
    FastQueue.h
    SafeDeletingQObjectPtr.h
    ScopedIncDec.h
    Span.h VirtualFunction.h FlagOps.h
    AutoRemovingFile.cpp AutoRemovingFile.h
    Proximity.cpp Proximity.h
    Property.h
    PropertyFactory.cpp PropertyFactory.h
    PropertySet.cpp PropertySet.h
    PerformanceTimer.cpp PerformanceTimer.h
    GridLineTraverser.cpp GridLineTraverser.h
    LineIntersectionScalar.cpp LineIntersectionScalar.h
    XmlMarshaller.cpp XmlMarshaller.h
    XmlUnmarshaller.cpp XmlUnmarshaller.h
    StaticPool.h
    DynamicPool.h
    NumericTraits.h
    TaskStatus.h
    VecNT.h
    VecT.h
    MatMNT.h
    MatT.h
    PriorityQueue.h
    Grid.h
    ValueConv.h
    Hashes.h
    Utils.cpp Utils.h)

add_library(foundation STATIC ${sources})
target_link_libraries(foundation PUBLIC ${Qt_Core_lib} ${Qt_Xml_lib} ${Qt_Gui_lib})
target_include_directories(foundation PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}")

# Boost is header-only for all components used in this project.
# On iOS, Boost is not found via find_package, so point directly at the headers.
if(IOS)
  target_include_directories(foundation PUBLIC /opt/homebrew/include)
else()
  target_include_directories(foundation PUBLIC ${Boost_INCLUDE_DIRS})
endif()

if (BUILD_TESTS)
  add_subdirectory(tests)
endif()