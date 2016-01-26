####################
# Check that given variables are set and all have non-empty values,
# die with an error otherwise.
#
# Params:
#   1. Variable name(s) to test.
#   2. (optional) Error message to print.

check_defined = \
    $(foreach 1,$1,$(__check_defined))
__check_defined = \
    $(if $(value $1),, \
      $(error Undefined $1$(if $(value 2), ($(strip $2)))))

### And this is how you use it ###

# $(call check_defined, MY_FLAG)

# $(call check_defined, OUT_DIR, build directory)
# $(call check_defined, BIN_DIR, where to put binary artifacts)
# $(call check_defined, LIB_INCLUDE_DIR LIB_SOURCE_DIR,  library path)


####################
# Prompts
pstart=$(shell echo "\033[0;34m")
pend=$(shell echo "\033[0m")
infoblue=$(info $(pstart)>>> $1$(pend))

### And this is how you use it ###
# $(call infoblue,generating files)