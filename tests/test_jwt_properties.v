import meiseayoung.hono
import rand
import time

// JWT 中间件属性测试
// Property-Based Testing for JWT functionality

const test_iterations = 100

struct PropertyTestStats {
mut:
	total_tests  int
	passed_tests int
	failed_tests int
}

fn (mut stats PropertyTestStats) run_property_test(test_name string, test_func fn () bool) {
	stats.total_tests++
	print('🔬 ${test_name}... ')

	if test_func() {
		stats.passed_tests++
		println('✅')
	} else {
		stats.failed_tests++
		println('❌')
	}
}

fn (stats PropertyTestStats) print_summary() {
	println('\n=== JWT 中间件属性测试总结 ===')
	println('总测试数: ${stats.total_tests}')
	println('通过: ${stats.passed_tests}')
	println('失败: ${stats.failed_tests}')

	if stats.failed_tests == 0 {
		println('🎉 所有属性测试通过！')
	} else {
		println('⚠️  有 ${stats.failed_tests} 个属性测试失败')
	}
}

// 生成随机的 subject
fn generate_random_subject() string {
	chars := 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
	len := rand.int_in_range(5, 30) or { 10 }
	mut subject := ''
	for _ in 0 .. len {
		idx := rand.int_in_range(0, chars.len) or { 0 }
		subject += chars[idx].ascii_str()
	}
	return subject
}

// 生成随机的 issuer
fn generate_random_issuer() string {
	prefixes := ['https://auth.', 'https://api.', 'https://']
	domains := ['example.com', 'test.org', 'myapp.io', 'service.net']
	prefix_idx := rand.int_in_range(0, prefixes.len) or { 0 }
	domain_idx := rand.int_in_range(0, domains.len) or { 0 }
	return prefixes[prefix_idx] + domains[domain_idx]
}


// 生成随机的密钥
fn generate_random_secret() string {
	chars := 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*'
	len := rand.int_in_range(32, 64) or { 32 }
	mut secret := ''
	for _ in 0 .. len {
		idx := rand.int_in_range(0, chars.len) or { 0 }
		secret += chars[idx].ascii_str()
	}
	return secret
}

// 生成随机的自定义声明
fn generate_random_claims() map[string]string {
	mut claims := map[string]string{}
	num_claims := rand.int_in_range(0, 5) or { 2 }
	
	for i in 0 .. num_claims {
		key := 'claim_${i}'
		value := generate_random_subject()
		claims[key] = value
	}
	
	return claims
}

// 生成随机的 JwtPayload
fn generate_random_payload() hono.JwtPayload {
	now := time.now().unix()
	
	return hono.JwtPayload{
		sub: generate_random_subject()
		iss: generate_random_issuer()
		aud: 'test-audience'
		exp: now + 3600  // 1 hour from now
		nbf: now - 60    // 1 minute ago
		iat: now
		jti: generate_random_subject()
		claims: generate_random_claims()
	}
}

// 随机选择算法
fn random_algorithm() hono.JwtAlgorithm {
	idx := rand.int_in_range(0, 3) or { 0 }
	return match idx {
		0 { hono.JwtAlgorithm.hs256 }
		1 { hono.JwtAlgorithm.hs384 }
		else { hono.JwtAlgorithm.hs512 }
	}
}

// ============================================================================
// Property 6: JWT Sign-Verify Round-Trip
// Feature: builtin-middleware, Property 6: JWT Sign-Verify Round-Trip
// Validates: Requirements 3.1, 3.4, 3.11
// 
// *For any* valid JwtPayload and secret, calling sign_jwt followed by verify_jwt 
// with the same secret SHALL return an equivalent payload.
// ============================================================================
fn test_property_6_jwt_sign_verify_roundtrip() bool {
	rand.seed([u32(time.now().unix()), u32(12345)])
	
	for i in 0 .. test_iterations {
		payload := generate_random_payload()
		secret := generate_random_secret()
		alg := random_algorithm()
		
		// 签名 JWT
		token := hono.sign_jwt(payload, secret, alg) or {
			println('  Iteration ${i}: Failed to sign JWT: ${err}')
			return false
		}
		
		// 验证 JWT
		verified_payload := hono.verify_jwt(token, secret, alg) or {
			println('  Iteration ${i}: Failed to verify JWT: ${err}')
			return false
		}
		
		// 验证 payload 字段
		if verified_payload.sub != payload.sub {
			println('  Iteration ${i}: Subject mismatch - expected "${payload.sub}", got "${verified_payload.sub}"')
			return false
		}
		
		if verified_payload.iss != payload.iss {
			println('  Iteration ${i}: Issuer mismatch - expected "${payload.iss}", got "${verified_payload.iss}"')
			return false
		}
		
		if verified_payload.aud != payload.aud {
			println('  Iteration ${i}: Audience mismatch - expected "${payload.aud}", got "${verified_payload.aud}"')
			return false
		}
		
		if verified_payload.exp != payload.exp {
			println('  Iteration ${i}: Exp mismatch - expected ${payload.exp}, got ${verified_payload.exp}')
			return false
		}
		
		if verified_payload.nbf != payload.nbf {
			println('  Iteration ${i}: Nbf mismatch - expected ${payload.nbf}, got ${verified_payload.nbf}')
			return false
		}
		
		if verified_payload.iat != payload.iat {
			println('  Iteration ${i}: Iat mismatch - expected ${payload.iat}, got ${verified_payload.iat}')
			return false
		}
		
		if verified_payload.jti != payload.jti {
			println('  Iteration ${i}: JTI mismatch - expected "${payload.jti}", got "${verified_payload.jti}"')
			return false
		}
		
		// 验证自定义声明
		for key, value in payload.claims {
			if key !in verified_payload.claims {
				println('  Iteration ${i}: Missing claim "${key}"')
				return false
			}
			if verified_payload.claims[key] != value {
				println('  Iteration ${i}: Claim "${key}" mismatch - expected "${value}", got "${verified_payload.claims[key]}"')
				return false
			}
		}
	}
	
	return true
}


// ============================================================================
// Property 7: JWT Expiration Enforcement
// Feature: builtin-middleware, Property 7: JWT Expiration Enforcement
// Validates: Requirements 3.2, 3.9
// 
// *For any* JWT with an exp claim in the past, verify_jwt SHALL return an error 
// when verifyOptions.exp is true.
// ============================================================================
fn test_property_7_jwt_expiration_enforcement() bool {
	rand.seed([u32(time.now().unix()), u32(54321)])
	
	for i in 0 .. test_iterations {
		now := time.now().unix()
		
		// 创建已过期的 payload
		mut payload := generate_random_payload()
		// 设置过期时间为过去（1秒到1小时前）
		seconds_ago := rand.int_in_range(1, 3600) or { 60 }
		payload.exp = now - seconds_ago
		
		secret := generate_random_secret()
		alg := random_algorithm()
		
		// 签名 JWT
		token := hono.sign_jwt(payload, secret, alg) or {
			println('  Iteration ${i}: Failed to sign JWT: ${err}')
			return false
		}
		
		// 使用带过期验证的选项验证 JWT
		verify_options := hono.JwtVerifyOptions{
			exp: true
			nbf: false
			iat: false
		}
		
		// 验证应该失败（因为 token 已过期）
		if _ := hono.verify_jwt_with_options(token, secret, alg, verify_options) {
			println('  Iteration ${i}: Expired JWT was accepted (should have been rejected)')
			return false
		}
	}
	
	return true
}

// ============================================================================
// Property 8: JWT Algorithm Consistency
// Feature: builtin-middleware, Property 8: JWT Algorithm Consistency
// Validates: Requirements 3.7
// 
// *For any* JWT signed with algorithm A, verification with algorithm B 
// (where A ≠ B) SHALL fail.
// ============================================================================
fn test_property_8_jwt_algorithm_consistency() bool {
	rand.seed([u32(time.now().unix()), u32(98765)])
	
	algorithms := [hono.JwtAlgorithm.hs256, hono.JwtAlgorithm.hs384, hono.JwtAlgorithm.hs512]
	
	for i in 0 .. test_iterations {
		payload := generate_random_payload()
		secret := generate_random_secret()
		
		// 随机选择签名算法
		sign_alg_idx := rand.int_in_range(0, algorithms.len) or { 0 }
		sign_alg := algorithms[sign_alg_idx]
		
		// 选择不同的验证算法
		mut verify_alg_idx := rand.int_in_range(0, algorithms.len) or { 0 }
		// 确保验证算法与签名算法不同
		for verify_alg_idx == sign_alg_idx {
			verify_alg_idx = rand.int_in_range(0, algorithms.len) or { 0 }
		}
		verify_alg := algorithms[verify_alg_idx]
		
		// 签名 JWT
		token := hono.sign_jwt(payload, secret, sign_alg) or {
			println('  Iteration ${i}: Failed to sign JWT: ${err}')
			return false
		}
		
		// 使用不同算法验证应该失败
		if _ := hono.verify_jwt(token, secret, verify_alg) {
			println('  Iteration ${i}: JWT verified with wrong algorithm (signed with ${sign_alg}, verified with ${verify_alg})')
			return false
		}
	}
	
	return true
}

fn main() {
	println('🚀 开始 JWT 中间件属性测试...')
	println('每个属性测试运行 ${test_iterations} 次迭代\n')

	mut stats := PropertyTestStats{}

	// 运行属性测试
	// Feature: builtin-middleware, Property 6: JWT Sign-Verify Round-Trip
	// Validates: Requirements 3.1, 3.4, 3.11
	stats.run_property_test('Property 6: JWT Sign-Verify Round-Trip', test_property_6_jwt_sign_verify_roundtrip)
	
	// Feature: builtin-middleware, Property 7: JWT Expiration Enforcement
	// Validates: Requirements 3.2, 3.9
	stats.run_property_test('Property 7: JWT Expiration Enforcement', test_property_7_jwt_expiration_enforcement)
	
	// Feature: builtin-middleware, Property 8: JWT Algorithm Consistency
	// Validates: Requirements 3.7
	stats.run_property_test('Property 8: JWT Algorithm Consistency', test_property_8_jwt_algorithm_consistency)

	// 打印测试总结
	stats.print_summary()
}
